# frozen_string_literal: true

module WritersRoom
  # Showrunner classifies user messages and routes them to the
  # appropriate specialist. Handles meta/process questions directly.
  # Manages round lifecycle: lead responds, reaction window, round close.
  class Showrunner
    ROUND_TIMEOUT     = 60   # Max seconds to wait for a round to complete
    REACTION_WINDOW   = 2    # Seconds after lead responds for reactions

    attr_reader :robot, :specialists

    # @param medium [Medium] the project medium (for specialist list)
    # @param project_context [Hash] project info for template rendering
    # @param bus [TypedBus::MessageBus] shared message bus
    # @param shared_memory [RobotLab::Memory] shared conversation memory
    # @param specialists [Hash<String, Specialist>] specialist roster
    # @param config [RobotLab::RunConfig] LLM configuration
    def initialize(medium:, project_context:, bus:, shared_memory:, specialists:, config:, logger: nil)
      @bus            = bus
      @shared_memory  = shared_memory
      @specialists    = specialists
      @round_responses = []
      @round_mutex     = Mutex.new
      @reaction_window_open = false
      @round_complete_callback = nil
      @logger         = logger

      context = build_context(medium, project_context)

      @robot = RobotLab.build(
        name:     "showrunner",
        template: :showrunner_system,
        context:  context,
        config:   config
      )

      subscribe_to_responses
      log("initialized with #{specialists.size} specialist(s)")
    end

    # Dispatch a user message to the appropriate specialist or handle as meta.
    # Returns collected responses when the round is complete.
    #
    # @param user_message [String] the user's input
    # @return [Array<Hash>] responses collected during this round
    def dispatch(user_message)
      @round_responses = []
      @reaction_window_open = false
      log("DISPATCH: received user message (#{user_message.length} chars)")

      # Check for direct addressing (@specialist_id message)
      if user_message =~ /\A@(\w+)\s+(.*)/m
        target_id = $1
        text = $2.strip
        if @specialists.key?(target_id)
          log("DISPATCH: direct address to @#{target_id}")
          return dispatch_to_lead(target_id, text)
        else
          log("DISPATCH: unknown direct address @#{target_id}, known: #{@specialists.keys.join(', ')}")
        end
      end

      # Classify via the showrunner robot
      log("CLASSIFY: sending to LLM for classification")
      result = @robot.run(user_message)
      classification = result.reply.to_s.strip
      log("CLASSIFY: result = '#{classification}'")

      if classification =~ /\ALEAD:\s*(\w+)/i
        lead_id = $1.strip
        if @specialists.key?(lead_id)
          log("DISPATCH: routing to specialist '#{lead_id}'")
          dispatch_to_lead(lead_id, user_message)
        else
          log("DISPATCH: classified lead '#{lead_id}' not found, handling as META")
          handle_meta(user_message)
        end
      elsif classification =~ /\AMETA:/i
        log("DISPATCH: handling as META")
        handle_meta(user_message)
      else
        log("DISPATCH: unrecognized classification, falling back to META")
        handle_meta(user_message)
      end
    end

    def reaction_window_open?
      @reaction_window_open
    end

    # Register a callback for round completion.
    def on_round_complete(&block)
      @round_complete_callback = block
    end

    def shutdown
      @robot = nil
    end

    private

    def build_context(medium, project_context)
      specialist_list = medium.chat_specialists.map do |spec|
        {
          id:          spec[:id],
          label:       spec[:label],
          description: spec[:description],
          domains:     Array(spec[:domains]),
        }
      end

      {
        project_name:    project_context[:project_name],
        project_concept: project_context[:concept],
        medium_label:    project_context[:medium_label],
        specialists:     specialist_list,
      }
    end

    def subscribe_to_responses
      @bus.subscribe(:responses) do |delivery|
        delivery.ack!
        log("BUS:responses: received from '#{delivery.message.from}' (#{delivery.message.content.to_s.length} chars)")
        handle_response(delivery.message)
      end
    end

    def handle_response(message)
      if message.from == "showrunner"
        log("BUS:responses: ignoring own message from showrunner")
        return
      end

      @round_mutex.synchronize do
        @round_responses << {
          from:    message.from,
          content: message.content,
          label:   specialist_label(message.from),
        }
        log("ROUND: collected response ##{@round_responses.size} from '#{message.from}'")
      end
    end

    def specialist_label(id)
      spec = @specialists[id]
      spec ? spec.label : id
    end

    # Dispatch to a specific specialist as the lead responder.
    def dispatch_to_lead(lead_id, user_text)
      record_user_message(user_text)

      dispatch_content = "[LEAD:#{lead_id}] [USER]#{user_text}[/USER]"
      message = RobotLab::RobotMessage.build(
        id:      Time.now.to_i,
        from:    "showrunner",
        content: dispatch_content
      )

      channel = :"dispatch_#{lead_id}"
      log("BUS:#{channel}: publishing [LEAD:#{lead_id}] message")
      Async { @bus.publish(channel, message) }
      log("BUS:#{channel}: publish completed (Async block returned)")

      wait_for_round
    end

    # Handle meta/process questions directly via the showrunner robot.
    def handle_meta(user_text)
      record_user_message(user_text)

      meta_prompt = <<~PROMPT
        The user asked a meta/process question. Answer it directly and concisely.
        You are the Showrunner — answer as yourself, not as a specialist.

        User: #{user_text}
      PROMPT

      result = @robot.run(meta_prompt)
      reply = result.reply.to_s

      @round_mutex.synchronize do
        @round_responses << {
          from:    "showrunner",
          content: reply,
          label:   "Showrunner",
        }
      end

      record_assistant_message("showrunner", reply)
      @round_responses.dup
    end

    # Wait for the lead to respond and the reaction window to close.
    def wait_for_round
      deadline = Time.now + ROUND_TIMEOUT
      lead_responded = false
      log("ROUND: waiting for responses (timeout=#{ROUND_TIMEOUT}s)")

      # Wait for lead response
      loop do
        break if Time.now > deadline

        @round_mutex.synchronize do
          lead_responded = @round_responses.any?
        end
        break if lead_responded

        sleep 0.5
      end

      if lead_responded
        log("ROUND: lead responded, opening reaction window (#{REACTION_WINDOW}s)")
        @reaction_window_open = true
        sleep [REACTION_WINDOW, [deadline - Time.now, 0].max].min
        @reaction_window_open = false
        log("ROUND: reaction window closed")
      else
        log("ROUND: TIMEOUT — no responses received after #{ROUND_TIMEOUT}s")
      end

      # Record all responses in shared memory
      @round_mutex.synchronize do
        log("ROUND: finalizing with #{@round_responses.size} response(s)")
        @round_responses.each do |resp|
          record_assistant_message(resp[:from], resp[:content])
        end
      end

      @round_responses.dup
    end

    def record_user_message(text)
      return unless @shared_memory

      RespondTool::RESPONSE_MUTEX.synchronize do
        history = @shared_memory.get(:chat_history) || []
        history << {
          from:      "user",
          content:   text,
          type:      :user,
          timestamp: Time.now.to_i,
        }
        @shared_memory.set(:chat_history, history)
      end
    end

    def record_assistant_message(from, content)
      return unless @shared_memory

      RespondTool::RESPONSE_MUTEX.synchronize do
        history = @shared_memory.get(:chat_history) || []
        history << {
          from:      from,
          content:   content,
          type:      :assistant,
          timestamp: Time.now.to_i,
        }
        @shared_memory.set(:chat_history, history)
      end
    end

    def log(message)
      @logger&.info("SHOWRUNNER: #{message}")
    end
  end
end
