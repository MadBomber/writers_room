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

    RECENT_DIALOG_LIMIT = 10

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

      @actor_context = build_template_context

      super(
        name:        @character_name.downcase.gsub(/\s+/, "_"),
        template:    :actor_system,
        context:     @actor_context,
        bus:         bus,
        config:      config,
        local_tools: build_tools
      )

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
        age:              fetch_field(:age, ""),
        personality:      extract_personality,
        voice_pattern:    extract_voice_pattern,
        background:       extract_background,
        current_arc:      extract_current_arc,
        relationships:    format_relationships,
        scene_name:       fetch_field(:scene_name, "", from: @scene_info),
        scene_number:     fetch_field(:scene_number, "", from: @scene_info),
        location:         fetch_field(:location, "", from: @scene_info),
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
      personality = fetch_field(:personality)
      return personality if personality

      traits = @character_info[:traits] || @character_info["traits"]
      return traits[:personality] || traits["personality"] if traits

      ""
    end

    def extract_voice_pattern
      fetch_field(:voice_pattern) || fetch_field(:speaking_style) || ""
    end

    def extract_background
      fetch_field(:background) || ""
    end

    def extract_current_arc
      fetch_field(:current_arc) || ""
    end

    def extract_objectives
      objectives = fetch_field(:objectives, "", from: @scene_info)
      objectives.is_a?(Array) ? objectives.join("; ") : objectives.to_s
    end

    def format_relationships
      rels = @character_info[:relationships] || @character_info["relationships"]
      return "No specific relationships defined" unless rels

      if rels.is_a?(Hash)
        rels.map { |person, status| "- #{person}: #{status}" }.join("\n")
      else
        rels.to_s
      end
    end

    # Reset the chat to a clean state using Robot's public update API.
    # Prevents history corruption from tool-only LLM responses
    # (empty text content blocks that Anthropic rejects).
    def fresh_chat!
      update(template: :actor_system, context: @actor_context)
    end

    def setup_message_handler
      on_message do |message|
        next if message.from == name
        next if heartbeat_message?(message.content)

        @messages_processed += 1
        @display&.incoming(name, message.from, message.content)

        fresh_chat!

        prompt = build_turn_prompt(message)

        begin
          result = run(prompt)
          debug_me("#{name} processed message ##{@messages_processed}")
        rescue => e
          debug_me("#{name} error processing message: #{e.message}")
        end
      end
    end

    # Build the prompt for this turn, including recent dialog history.
    def build_turn_prompt(message)
      lines = ["[#{message.from}]: #{message.content}"]

      if @shared_memory
        history = @shared_memory.get(:dialog_history) || []
        recent = history.last(RECENT_DIALOG_LIMIT)

        if recent.any?
          lines << ""
          lines << "[Recent dialog]"
          recent.each do |entry|
            emotion_tag = entry[:emotion] ? " [#{entry[:emotion]}]" : ""
            lines << "#{entry[:from]}#{emotion_tag}: #{entry[:content]}"
          end
        end
      end

      lines.join("\n")
    end

    def heartbeat_message?(content)
      content.to_s.start_with?("[ROOM STATUS]")
    end
  end
end
