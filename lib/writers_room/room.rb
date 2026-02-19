# frozen_string_literal: true


module WritersRoom
  # Scene container that holds the bus, shared memory, and actor roster.
  #
  # Modeled on RobotLab example 16's Room pattern: actors communicate
  # through a shared bus channel, use shared memory for persistence,
  # and the Room coordinates completion detection.
  class Room
    attr_reader :bus, :memory, :actors, :display, :config, :scene_info

    # @param display [Display] terminal output formatter
    # @param config [RobotLab::RunConfig] shared LLM configuration
    # @param scene_info [Hash] scene metadata (scene_name, characters, etc.)
    def initialize(display:, config:, scene_info:)
      @bus     = TypedBus::MessageBus.new
      @memory  = RobotLab::Memory.new(enable_cache: false)
      @display = display
      @config  = config
      @scene_info = scene_info
      @actors  = {}

      # Shared broadcast channel for the scene
      @bus.add_channel(:scene)
    end

    # Add an actor to the room.
    #
    # @param name [String] character name
    # @param character_info [Hash] character metadata from file
    # @return [Actor] the created actor
    def add_actor(name, character_info:)
      actor = Actor.new(
        character_info: character_info,
        scene_info:     @scene_info,
        bus:            @bus,
        shared_memory:  @memory,
        display:        @display,
        room:           self,
        config:         @config
      )
      @actors[name] = actor
      actor
    end

    # Seed the scene by publishing the opening prompt from the "director".
    # Uses a director identity so actors don't filter it as their own message.
    #
    # @param opening_prompt [String] initial context to send
    def seed(opening_prompt)
      return if @actors.empty?

      message = RobotLab::RobotMessage.build(
        id: 0,
        from: "director",
        content: opening_prompt
      )
      Async { @bus.publish(:scene, message) }
    end

    # Wait for the scene to complete.
    #
    # @param timeout [Integer] max seconds to wait
    # @param max_lines [Integer] max dialog lines before auto-complete
    # @param poll_interval [Integer] seconds between polls
    # @param heartbeat_interval [Integer] seconds between heartbeats
    # @return [Boolean] true if completed, false if timed out
    def wait_for_completion(timeout: 300, max_lines: 50, poll_interval: 2, heartbeat_interval: 30)
      deadline = Time.now + timeout
      last_heartbeat = Time.now
      @last_line_count = 0

      loop do
        # Check if scene was marked complete by an actor
        if @memory.key?(:scene_complete)
          @display.director_note("Scene complete!")
          return true
        end

        # Check line count safety net
        history = @memory.get(:dialog_history) || []
        if history.length >= max_lines
          @display.director_note("Maximum lines reached (#{max_lines})")
          @memory.set(:scene_complete, true)
          return true
        end

        # Check timeout
        if Time.now > deadline
          @display.director_note("Scene timeout reached (#{timeout}s)")
          return false
        end

        # Heartbeat: display status and nudge actors if dialog has stalled
        if Time.now - last_heartbeat >= heartbeat_interval
          send_heartbeat(history.length, max_lines)

          if history.length == @last_line_count
            send_director_nudge(history)
          end

          @last_line_count = history.length
          last_heartbeat = Time.now
        end

        sleep poll_interval
      end
    end

    # Assemble the transcript from shared memory.
    #
    # @return [Array<Hash>] dialog entries
    def assemble_transcript
      @memory.get(:dialog_history) || []
    end

    # Disconnect all actors and close the bus.
    def shutdown
      @actors.each_value do |actor|
        actor.disconnect
        @display.info("  - #{actor.name} has left the stage")
      end
      @bus.close_all
      @actors.clear
      @display.close
    end

    private

    def send_heartbeat(current_lines, max_lines)
      remaining = max_lines - current_lines
      status = "[ROOM STATUS] #{current_lines}/#{max_lines} lines spoken. #{remaining} remaining."
      @display.info(status)
    end

    # Send a director nudge to re-engage actors when dialog has stalled.
    def send_director_nudge(history)
      characters = @actors.keys.join(", ")
      last_line = history.last
      context = last_line ? "The last line was from #{last_line[:from]}." : ""

      nudge = "[DIRECTOR] The scene needs to continue. #{context} " \
              "Characters present: #{characters}. Keep the dialog going — use the speak tool."

      message = RobotLab::RobotMessage.build(
        id: Time.now.to_i,
        from: "director",
        content: nudge
      )
      Async { @bus.publish(:scene, message) }
    end
  end
end
