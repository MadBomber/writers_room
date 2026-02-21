# frozen_string_literal: true

module WritersRoom
  # Domain-focused specialist robot for multi-robot chat.
  #
  # Each specialist has expertise in specific domains (e.g. characters,
  # plot structure, world-building) and responds when dispatched by
  # the Showrunner. Follows the Actor pattern but for chat mode:
  # - Subscribes to :dispatch channel for addressed requests
  # - Subscribes to :responses channel to see other specialists (for reactions)
  # - Uses RespondTool/ReactTool instead of SpeakTool
  # - Preserves conversation context across the session (no fresh_chat!)
  class Specialist < RobotLab::Robot
    attr_reader :spec_config, :domains, :label
    attr_accessor :shared_memory, :chat_room, :responded

    RECENT_HISTORY_LIMIT = 20

    # @param spec_config [Hash] specialist definition from medium YAML
    #   Expected keys: :id, :label, :description, :domains
    # @param project_context [Hash] project info for template rendering
    # @param project_path [String] path to project directory
    # @param bus [TypedBus::MessageBus] shared message bus
    # @param shared_memory [RobotLab::Memory] shared conversation memory
    # @param config [RobotLab::RunConfig] LLM configuration
    def initialize(spec_config:, project_context:, project_path:, bus:, shared_memory:, config:, logger: nil)
      @spec_config   = spec_config
      @domains       = Array(spec_config[:domains])
      @label         = spec_config[:label]
      @shared_memory = shared_memory
      @chat_room     = nil
      @project_path  = project_path
      @logger        = logger
      @private_memory = RobotLab::Memory.new(enable_cache: false)

      context = build_template_context(spec_config, project_context)

      super(
        name:        spec_config[:id].to_s,
        template:    :specialist_system,
        context:     context,
        bus:         bus,
        config:      config,
        local_tools: build_tools
      )

      setup_dispatch_handler
      subscribe_to_channels
    end

    def disconnect
      if @bus
        @bus.unsubscribe(:"dispatch_#{name}", @dispatch_subscriber_id) if @dispatch_subscriber_id
        @bus.unsubscribe(:responses, @responses_subscriber_id) if @responses_subscriber_id
        @dispatch_subscriber_id = nil
        @responses_subscriber_id = nil
      end
      super
    end

    private

    def build_template_context(spec_config, project_context)
      {
        specialist_label:       spec_config[:label],
        specialist_id:          spec_config[:id],
        domains:                Array(spec_config[:domains]),
        specialist_description: spec_config[:description],
        project_name:           project_context[:project_name],
        project_concept:        project_context[:concept],
        medium_label:           project_context[:medium_label],
        project_state:          project_context[:project_state],
      }
    end

    def build_tools
      tools = [
        RespondTool.new(robot: self),
        ReactTool.new(robot: self),
        ReadMemoryTool.new(robot: self),
        WriteMemoryTool.new(robot: self),
        ListMemoryTool.new(robot: self),
        MarkRoundCompleteTool.new(robot: self),
      ]

      if @project_path
        tools << ReadFileTool.new(project_path: @project_path, robot: self)
        tools << ListDirectoryTool.new(project_path: @project_path, robot: self)
        tools << OpenEditorTool.new(project_path: @project_path, robot: self)
      end

      tools
    end

    def setup_dispatch_handler
      on_message do |message|
        next if message.from == name

        if dispatch_for_me?(message.content)
          log("on_message: dispatch for me — from '#{message.from}'")
          handle_dispatch(message)
        elsif reaction_eligible?(message)
          log("on_message: reaction eligible — from '#{message.from}'")
          handle_potential_reaction(message)
        else
          log("on_message: ignoring — from '#{message.from}', dispatch_for_me?=#{dispatch_for_me?(message.content)}")
        end
      end
    end

    def subscribe_to_channels
      return unless @bus

      dispatch_channel = :"dispatch_#{name}"
      @dispatch_subscriber_id = @bus.subscribe(dispatch_channel) do |delivery|
        log("BUS:#{dispatch_channel}: received delivery from '#{delivery.message.from}'")
        send(:handle_incoming_delivery, delivery)
      end

      @responses_subscriber_id = @bus.subscribe(:responses) do |delivery|
        log("BUS:responses: received delivery from '#{delivery.message.from}'")
        send(:handle_incoming_delivery, delivery)
      end

      log("subscribed to :#{dispatch_channel} and :responses channels")
    end

    # Check if a dispatch message is addressed to this specialist.
    def dispatch_for_me?(content)
      content.to_s.include?("[LEAD:#{name}]")
    end

    # Check if a response from another specialist warrants a reaction.
    def reaction_eligible?(message)
      return false if message.from == name
      return false if message.from == "showrunner"
      return false unless @chat_room&.reaction_window_open?

      # Only react if there's domain overlap with the topic
      true
    end

    def handle_dispatch(message)
      user_text = extract_user_text(message.content)
      prompt = build_lead_prompt(user_text)

      @responded = false
      log("handle_dispatch: extracted user text (#{user_text.length} chars), calling LLM")

      begin
        result = run(prompt)
        log("handle_dispatch: LLM returned — responded=#{@responded}, stop_reason=#{result&.stop_reason}, has_text=#{!result&.last_text_content.to_s.strip.empty?}")

        unless @responded
          fallback = result&.last_text_content
          if fallback && !fallback.strip.empty?
            log("handle_dispatch: FALLBACK — RespondTool not used, publishing LLM text (#{fallback.length} chars)")
            send_message(to: :responses, content: fallback)
          else
            log("handle_dispatch: FALLBACK — no text content to publish either")
          end
        end
      rescue => e
        log("handle_dispatch: ERROR — #{e.class}: #{e.message}")
        debug_me "#{name} error handling dispatch: #{e.message}"
      end
    end

    def handle_potential_reaction(message)
      unless @chat_room&.reaction_window_open?
        log("handle_reaction: window closed, skipping")
        return
      end

      prompt = build_reaction_prompt(message)
      log("handle_reaction: calling LLM for reaction to '#{message.from}'")

      begin
        run(prompt)
        log("handle_reaction: LLM returned")
      rescue => e
        log("handle_reaction: ERROR — #{e.class}: #{e.message}")
        debug_me "#{name} error handling reaction: #{e.message}"
      end
    end

    def extract_user_text(content)
      if content =~ /\[USER\](.*?)\[\/USER\]/m
        $1.strip
      else
        content.to_s.sub(/\[LEAD:\w+\]\s*/, "").strip
      end
    end

    def build_lead_prompt(user_text)
      lines = ["The user asks: #{user_text}"]

      if @shared_memory
        history = @shared_memory.get(:chat_history) || []
        recent = history.last(RECENT_HISTORY_LIMIT)

        if recent.any?
          lines << ""
          lines << "[Recent conversation]"
          recent.each do |entry|
            lines << "#{entry[:from]}: #{entry[:content]}"
          end
        end
      end

      lines << ""
      lines << "You are the lead responder. Use the respond tool to deliver your answer, then mark_round_complete."

      lines.join("\n")
    end

    def build_reaction_prompt(message)
      <<~PROMPT
        #{message.from} just responded to the user: #{message.content}

        If you disagree with something, catch an error, or have a critical addition from your domain expertise, use the react tool. Otherwise, do nothing — use mark_round_complete to signal you're done.

        Only react if it's important. Keep reactions to 1-2 sentences.
      PROMPT
    end

    def log(message)
      @logger&.info("SPECIALIST[#{name}]: #{message}")
    end
  end
end
