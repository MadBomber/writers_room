# frozen_string_literal: true
##########################################################
###
##  File: actor.rb
##  Desc: AI-powered Actor for multi-character dialog generation
##  By:   Dewayne VanHoozer (dvanhoozer@gmail.com)
#

require "debug_me"
include DebugMe

module WritersRoom
  # AI-powered Actor that uses RobotLab's template system, tools, and
  # bus messaging to participate in multi-character scenes.
  #
  # Follows the RobotLab example 16 Writer pattern:
  # - Uses template + context instead of inline heredoc prompts
  # - Equipped with tools (SpeakTool, ReadMemoryTool, etc.)
  # - Reacts to bus messages via on_message handler
  # - Resets chat before each message (shared memory is persistence)
  #
  class Actor < RobotLab::Robot
    attr_reader :character_name, :character_info, :scene_info
    attr_accessor :shared_memory, :display, :room

    # Initialize an Actor with character information.
    #
    # @param character_info [Hash] Character details (from .md front matter)
    # @param scene_info [Hash] Scene details (from .md front matter)
    # @param bus [TypedBus::MessageBus] Shared message bus
    # @param shared_memory [RobotLab::Memory] Shared scene memory
    # @param display [Display] Terminal output formatter
    # @param room [Room] Parent room container
    # @param config [RobotLab::RunConfig, nil] Shared LLM configuration
    def initialize(character_info:, scene_info:, bus:, shared_memory: nil, display: nil, room: nil, config: nil)
      @character_info = character_info
      @character_name = character_info[:name] || character_info["name"]
      @scene_info = scene_info
      @shared_memory = shared_memory
      @display = display
      @room = room
      @messages_processed = 0

      validate_character_info!

      super(
        name:        @character_name.downcase.gsub(/\s+/, "_"),
        template:    :actor_system,
        context:     build_template_context,
        bus:         bus,
        config:      config,
        local_tools: build_tools
      )

      setup_room_subscription
      setup_message_handler

      debug_me("Actor initialized with template + tools") { @character_name }
    end

    private

    def validate_character_info!
      raise ArgumentError, "Character name is required" unless @character_name
    end

    def build_tools
      [
        SpeakTool.new(robot: self),
        ReadMemoryTool.new(robot: self),
        WriteMemoryTool.new(robot: self),
        ListMemoryTool.new(robot: self),
        MarkSceneCompleteTool.new(robot: self),
      ]
    end

    # Build the context hash for the actor_system template.
    # Maps character/scene data to template parameters.
    def build_template_context
      {
        character_name:   @character_name,
        age:              fetch_field(:age, 16),
        personality:      extract_personality,
        voice_pattern:    extract_voice_pattern,
        sport:            fetch_field(:sport, ""),
        current_arc:      extract_current_arc,
        relationships:    format_relationships,
        scene_name:       fetch_field(:scene_name, "", from: @scene_info),
        scene_number:     fetch_field(:scene_number, "", from: @scene_info),
        location:         fetch_field(:location, "", from: @scene_info),
        week:             fetch_field(:week, "", from: @scene_info),
        objectives:       extract_objectives,
        characters_present: Array(fetch_field(:characters, [], from: @scene_info)).join(", "),
        project_concept:  fetch_field(:concept, "", from: @scene_info),
      }
    end

    # Fetch a field from a hash, trying symbol then string keys.
    def fetch_field(key, default = nil, from: @character_info)
      from[key.to_sym] || from[key.to_s] || default
    end

    # Extract personality from either top-level or body sections.
    def extract_personality
      # Try top-level field first
      personality = fetch_field(:personality)
      return personality if personality

      # Try traits hash (from Producer-created files)
      traits = @character_info[:traits] || @character_info["traits"]
      return traits[:personality] || traits["personality"] if traits

      ""
    end

    # Extract voice pattern from either top-level or body.
    def extract_voice_pattern
      fetch_field(:voice_pattern) || ""
    end

    # Extract current arc from character info or body.
    def extract_current_arc
      fetch_field(:current_arc) || ""
    end

    # Extract objectives from scene info.
    def extract_objectives
      objectives = fetch_field(:objectives, "", from: @scene_info)
      objectives.is_a?(Array) ? objectives.join("; ") : objectives.to_s
    end

    # Format relationships for the template.
    def format_relationships
      rels = @character_info[:relationships] || @character_info["relationships"]
      return "No specific relationships defined" unless rels

      if rels.is_a?(Hash)
        rels.map { |person, status| "- #{person}: #{status}" }.join("\n")
      else
        rels.to_s
      end
    end

    def setup_room_subscription
      @bus.subscribe(:scene) do |delivery|
        handle_incoming_delivery(delivery)
      end
    end

    # Reset the chat to a clean state with system prompt and tools.
    # Prevents history corruption from tool-only LLM responses
    # (empty text content blocks that Anthropic rejects).
    def fresh_chat!
      resolved_model = @config&.model || RobotLab.config.ruby_llm.model
      @chat = RubyLLM.chat(model: resolved_model)
      apply_template_to_chat(@build_context) if @template
      @chat.with_instructions(@system_prompt) if @system_prompt
      @chat.with_temperature(@config.temperature) if @config&.temperature

      filtered = filtered_tools([])
      @chat.with_tools(*filtered) if filtered.any?
    end

    def setup_message_handler
      on_message do |message|
        # Don't respond to your own messages
        next if message.from == name

        @messages_processed += 1
        @display&.incoming(name, message.from, message.content)

        # Fresh chat for each message -- shared memory is our persistence
        fresh_chat!

        # Build prompt with current memory context
        memory_keys = @shared_memory&.keys || []
        prompt = "[#{message.from}]: #{message.content}"
        prompt += "\n\n[Memory keys: #{memory_keys.join(', ')}]" if memory_keys.any?

        begin
          result = run(prompt)
          debug_me("#{name} processed message ##{@messages_processed}")
        rescue => e
          debug_me("#{name} error processing message: #{e.message}")
        end
      end
    end

    # Handle incoming bus delivery (called from subscription)
    def handle_incoming_delivery(delivery)
      message = delivery.message
      msg_content = message.respond_to?(:content) ? message.content : message
      delivery.ack!
    end
  end
end
