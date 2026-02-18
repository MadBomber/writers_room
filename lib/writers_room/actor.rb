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
  class Actor < RobotLab::Robot
    attr_reader :character_name, :character_info, :scene_info, :conversation_history

    # Initialize an Actor with character information
    #
    # @param character_info [Hash] Character details
    # @param scene_info [Hash] Scene details
    # @param bus [TypedBus::MessageBus] Shared message bus
    def initialize(character_info:, scene_info:, bus:)
      @character_info = character_info
      @character_name = character_info[:name] || character_info["name"]
      @scene_info = scene_info
      @conversation_history = []

      validate_character_info!

      super(
        name: @character_name.downcase.gsub(/\s+/, "_"),
        system_prompt: build_system_prompt,
        bus: bus
      )

      setup_message_handler

      debug_me("Actor initialized") { :character_name }
    end

    # Generate dialog based on current context
    #
    # @param prompt_context [String] Optional additional context
    # @return [String] Generated dialog line
    def generate_dialog(prompt_context: nil)
      user_prompt = build_user_prompt(prompt_context)

      debug_me("Generating dialog for #{@character_name}") do
        [system_prompt.length, user_prompt.length]
      end

      result = run(user_prompt)
      dialog = result.reply&.strip || ""

      # Clean up the dialog
      dialog = dialog
        .gsub(/^["']|["']$/, "")
        .gsub(/^\w+:\s*/, "")

      @conversation_history << { speaker: @character_name, line: dialog, timestamp: Time.now }

      dialog
    end

    # Send dialog to the scene via bus
    #
    # @param dialog [String] The dialog to send
    # @param emotion [String] Optional emotional tone
    # @param addressing [String] Optional character being addressed
    def speak(dialog, emotion: nil, addressing: nil)
      payload = DialogPayload.new(
        from: @character_name,
        content: dialog,
        scene: @scene_info[:scene_number],
        emotion: emotion,
        addressing: addressing
      )

      send_message(to: :scene, content: payload.to_h)

      debug_me("#{@character_name} spoke") { dialog }
    end

    # React to incoming dialog and decide whether to respond
    #
    # @param message_data [Hash] Incoming message data
    # @return [Boolean] Whether the actor responded
    def react_to(message_data)
      return false if message_data[:from] == @character_name

      @conversation_history << {
        speaker: message_data[:from],
        line: message_data[:content],
        timestamp: Time.now,
      }

      if should_respond?(message_data)
        debug_me("#{@character_name} deciding to respond to #{message_data[:from]}")

        response = generate_dialog(
          prompt_context: "Responding to #{message_data[:from]}: '#{message_data[:content]}'",
        )

        speak(response)
        return true
      end

      false
    end

    private

    def validate_character_info!
      raise ArgumentError, "Character name is required" unless @character_name

      debug_me("Validated character info for #{@character_name}")
    end

    def setup_message_handler
      on_message do |message|
        msg_content = message.content
        msg_content = msg_content.transform_keys(&:to_sym) if msg_content.is_a?(Hash)

        next unless msg_content.is_a?(Hash)
        next unless msg_content[:scene].to_s == @scene_info[:scene_number].to_s

        react_to(msg_content)
      end
    end

    def build_system_prompt
      <<~SYSTEM
        You are #{@character_name}, a character in a comedic teen play.

        CHARACTER PROFILE:
        Name: #{@character_name}
        Age: #{@character_info[:age] || @character_info["age"] || 16}
        Personality: #{@character_info[:personality] || @character_info["personality"]}
        Voice Pattern: #{@character_info[:voice_pattern] || @character_info["voice_pattern"]}
        Sport/Activity: #{@character_info[:sport] || @character_info["sport"]}

        CURRENT CHARACTER ARC:
        #{@character_info[:current_arc] || @character_info["current_arc"]}

        RELATIONSHIPS:
        #{format_relationships}

        SCENE CONTEXT:
        Scene: #{@scene_info[:scene_name] || @scene_info["scene_name"]} (Scene #{@scene_info[:scene_number] || @scene_info["scene_number"]})
        Location: #{@scene_info[:location] || @scene_info["location"]}
        Week: #{@scene_info[:week] || @scene_info["week"]} of the semester
        Your Objective: #{@scene_info[:objectives] || @scene_info["objectives"]}
        Other Characters Present: #{Array(@scene_info[:characters] || @scene_info["characters"]).join(", ")}

        INSTRUCTIONS:
        - Stay completely in character
        - Use your unique voice pattern consistently
        - Respond naturally to other characters based on your relationships
        - Keep dialog authentic to a teenager
        - Include appropriate humor based on your personality
        - React to the scene objectives and context
        - Do not narrate actions, only speak dialog
        - Keep responses concise (1-3 sentences typically)
        - Use contractions and natural speech patterns

        RESPONSE FORMAT:
        Respond with ONLY the dialog your character would say. No quotation marks, no stage directions, no character name prefix. Just the words #{@character_name} would speak.
      SYSTEM
    end

    def build_user_prompt(additional_context = nil)
      prompt = "CONVERSATION SO FAR:\n"

      if @conversation_history.empty?
        prompt += "(Scene just started - you may initiate conversation if appropriate)\n"
      else
        recent_history = @conversation_history.last(10)
        recent_history.each do |exchange|
          prompt += "#{exchange[:speaker]}: #{exchange[:line]}\n"
        end
      end

      prompt += "\nADDITIONAL CONTEXT:\n#{additional_context}\n" if additional_context

      prompt += "\nWhat does #{@character_name} say?"

      prompt
    end

    def format_relationships
      rels = @character_info[:relationships] || @character_info["relationships"]
      return "No specific relationships defined" unless rels

      rels.map do |person, status|
        "- #{person}: #{status}"
      end.join("\n")
    end

    def should_respond?(message_data)
      last_speaker = @conversation_history[-2]&.dig(:speaker)

      return true if message_data[:content]&.include?(@character_name)

      return true if last_speaker != @character_name &&
                     @conversation_history.last(3).count { |h| h[:speaker] == @character_name } < 2

      return true if rand < 0.10

      false
    end
  end
end
