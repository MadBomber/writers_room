# frozen_string_literal: true
##########################################################
###
##  File: actor.rb
##  Desc: AI-powered Actor for multi-character dialog generation
##  By:   Dewayne VanHoozer (dvanhoozer@gmail.com)
#

require "debug_me"
include DebugMe

require "json"
require "redis"
require "ruby_llm"
require "smart_message"

# Load message classes
require_relative "messages/dialog_message"
require_relative "messages/scene_control_message"

module WritersRoom
  class Actor
    attr_reader :character_name, :character_info, :scene_info, :conversation_history

    # Initialize an Actor with character information
    #
    # @param character_info [Hash] Character details
    # @option character_info [String] :name Character's name (required)
    # @option character_info [String] :personality Character traits and behaviors
    # @option character_info [String] :voice_pattern How the character speaks
    # @option character_info [Hash] :relationships Current relationship statuses
    # @option character_info [String] :current_arc Where they are in their character arc
    # @option character_info [String] :sport Associated sport/activity
    # @option character_info [Integer] :age Character's age
    def initialize(character_info)
      @character_info = character_info
      @character_name = character_info[:name] || character_info["name"]
      @scene_info = {}
      @conversation_history = []
      @llm = nil
      @running = false

      validate_character_info!
      setup_llm

      debug_me("Actor initialized") { :character_name }
    end

    # Set the current scene information
    #
    # @param scene_info [Hash] Scene details
    # @option scene_info [Integer] :scene_number Which scene this is
    # @option scene_info [String] :scene_name Name/title of the scene
    # @option scene_info [String] :location Where the scene takes place
    # @option scene_info [Array<String>] :characters List of characters in scene
    # @option scene_info [String] :objectives What this character wants in scene
    # @option scene_info [String] :context Additional scene context
    # @option scene_info [Integer] :week Which week in the timeline
    def set_scene(scene_info)
      @scene_info = scene_info
      @conversation_history = [] # Reset history for new scene

      debug_me("Scene set for #{@character_name}") do
        [@scene_info[:scene_name], @scene_info[:scene_number]]
      end
    end

    # Start the actor listening and responding to messages
    #
    # @param channel [String] Redis channel to subscribe to
    def perform(channel: "writers_room:dialog")
      @running = true

      debug_me("#{@character_name} starting performance on channel: #{channel}")

      # Subscribe to the dialog channel
      subscribe_to_dialog(channel) do |message_data|
        break unless @running

        process_message(message_data)
      end
    end

    # Stop the actor
    def stop
      @running = false
      debug_me("#{@character_name} stopping")
    end

    # Generate dialog based on current context
    #
    # @param prompt_context [String] Optional additional context
    # @return [String] Generated dialog line
    def generate_dialog(prompt_context: nil)
      system_prompt = build_system_prompt
      user_prompt = build_user_prompt(prompt_context)

      debug_me("Generating dialog for #{@character_name}") do
        [system_prompt.length, user_prompt.length]
      end

      response = @llm.chat([
                             { role: "system", content: system_prompt },
                             { role: "user", content: user_prompt },
                           ])

      dialog = extract_dialog(response)
      @conversation_history << { speaker: @character_name, line: dialog, timestamp: Time.now }

      dialog
    end

    # Send dialog to the scene via SmartMessage/Redis
    #
    # @param dialog [String] The dialog to send
    # @param channel [String] Redis channel to publish to
    # @param emotion [String] Optional emotional tone
    # @param addressing [String] Optional character being addressed
    def speak(dialog, channel: "writers_room:dialog", emotion: nil, addressing: nil)
      message = DialogMessage.new(
        from: @character_name,
        content: dialog,
        scene: @scene_info[:scene_number],
        timestamp: Time.now.to_i,
        emotion: emotion,
        addressing: addressing,
      )

      message.publish(channel)

      debug_me("#{@character_name} spoke") { dialog }
    end

    # React to incoming dialog and decide whether to respond
    #
    # @param message_data [Hash] Incoming message data
    # @return [Boolean] Whether the actor responded
    def react_to(message_data)
      # Don't react to own messages
      return false if message_data[:from] == @character_name

      # Add to conversation history
      @conversation_history << {
        speaker: message_data[:from],
        line: message_data[:content],
        timestamp: Time.now,
      }

      # Decide whether to respond based on context
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

    def setup_llm
      # Initialize RubyLLM client with Ollama provider and gpt-oss model
      # Can be overridden with environment variables:
      #   RUBY_LLM_PROVIDER - provider name (default: ollama)
      #   RUBY_LLM_MODEL - model name (default: gpt-oss)
      #   OLLAMA_URL - Ollama server URL (default: http://localhost:11434)

      provider = ENV["RUBY_LLM_PROVIDER"] || "ollama"
      model = ENV["RUBY_LLM_MODEL"] || "gpt-oss"
      base_url = ENV["OLLAMA_URL"] || "http://localhost:11434"

      @llm = RubyLLM::Client.new(
        provider: provider,
        model: model,
        base_url: base_url,
        timeout: 120, # 2 minutes timeout for longer responses
      )

      debug_me("LLM setup complete for #{@character_name}") do
        [provider, model, base_url]
      end
    end

    # Build the system prompt that defines the character
    def build_system_prompt
      <<~SYSTEM
        You are #{@character_name}, a character in a comedic teen play.

        CHARACTER PROFILE:
        Name: #{@character_name}
        Age: #{@character_info[:age] || 16}
        Personality: #{@character_info[:personality]}
        Voice Pattern: #{@character_info[:voice_pattern]}
        Sport/Activity: #{@character_info[:sport]}

        CURRENT CHARACTER ARC:
        #{@character_info[:current_arc]}

        RELATIONSHIPS:
        #{format_relationships}

        SCENE CONTEXT:
        Scene: #{@scene_info[:scene_name]} (Scene #{@scene_info[:scene_number]})
        Location: #{@scene_info[:location]}
        Week: #{@scene_info[:week]} of the semester
        Your Objective: #{@scene_info[:objectives]}
        Other Characters Present: #{@scene_info[:characters]&.join(", ")}

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

    # Build the user prompt for the current situation
    def build_user_prompt(additional_context = nil)
      prompt = "CONVERSATION SO FAR:\n"

      if @conversation_history.empty?
        prompt += "(Scene just started - you may initiate conversation if appropriate)\n"
      else
        # Include last 10 exchanges for context
        recent_history = @conversation_history.last(10)
        recent_history.each do |exchange|
          prompt += "#{exchange[:speaker]}: #{exchange[:line]}\n"
        end
      end

      prompt += "\nADDITIONAL CONTEXT:\n#{additional_context}\n" if additional_context

      prompt += "\nWhat does #{@character_name} say?"

      prompt
    end

    # Format relationship information for the prompt
    def format_relationships
      return "No specific relationships defined" unless @character_info[:relationships]

      @character_info[:relationships].map do |person, status|
        "- #{person}: #{status}"
      end.join("\n")
    end

    # Extract dialog from LLM response
    def extract_dialog(response)
      # RubyLLM response handling - adjust based on actual gem API
      dialog = if response.is_a?(String)
          response
        elsif response.respond_to?(:content)
          response.content
        elsif response.respond_to?(:text)
          response.text
        elsif response.is_a?(Hash) && response[:content]
          response[:content]
        else
          response.to_s
        end

      # Clean up the dialog
      dialog.strip
            .gsub(/^["']|["']$/, "") # Remove surrounding quotes
            .gsub(/^\w+:\s*/, "") # Remove character name prefix if present
    end

    # Subscribe to dialog messages via SmartMessage
    def subscribe_to_dialog(channel, &block)
      DialogMessage.subscribe(channel) do |message|
        next unless message.scene == @scene_info[:scene_number]

        message_data = {
          from: message.from,
          content: message.content,
          scene: message.scene,
          timestamp: message.timestamp,
          emotion: message.emotion,
          addressing: message.addressing,
        }

        block.call(message_data)
      end
    end

    # Decide whether to respond to a message
    def should_respond?(message_data)
      last_speaker = @conversation_history[-2]&.dig(:speaker)

      # Always respond if directly addressed (name mentioned)
      return true if message_data[:content].include?(@character_name)

      # Respond if it's your turn in conversation flow
      # (last speaker wasn't you, and you haven't spoken recently)
      return true if last_speaker != @character_name &&
                     @conversation_history.last(3).count { |h| h[:speaker] == @character_name } < 2

      # Random chance to interject (10%)
      return true if rand < 0.10

      # Otherwise, listen
      false
    end
  end
end
