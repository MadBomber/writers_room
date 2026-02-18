# frozen_string_literal: true
##########################################################
###
##  File: director.rb
##  Desc: Director to orchestrate multiple actors in a scene
##  By:   Dewayne VanHoozer (dvanhoozer@gmail.com)
#

require "debug_me"
include DebugMe

require "yaml"

module WritersRoom
  class Director
    attr_reader :scene_info, :actors, :transcript

    # Initialize the Director
    #
    # @param scene_file [String] Path to scene YAML file
    # @param character_dir [String] Directory containing character YAML files (optional, auto-detected)
    # @param max_lines [Integer] Maximum dialog lines before scene ends
    def initialize(scene_file:, character_dir: nil, max_lines: nil)
      @scene_file = scene_file
      @character_dir = character_dir || detect_character_dir(scene_file)
      @scene_info = load_scene
      @actors = []
      @transcript = []
      @running = false
      @max_lines = max_lines || ENV["MAX_LINES"]&.to_i || 50
      @bus = TypedBus::MessageBus.new

      debug_me("Director initialized") {
        [@scene_info[:scene_name], @scene_info[:characters].join(", "), @character_dir]
      }
    end

    # Start the scene with all actors
    def action!
      puts <<~HEADER

        #{"=" * 60}
        SCENE #{@scene_info[:scene_number]}: #{@scene_info[:scene_name]}
        Location: #{@scene_info[:location]}
        Characters: #{@scene_info[:characters].join(", ")}
        #{"=" * 60}

      HEADER

      @running = true

      create_actors
      subscribe_to_scene
      initiate_scene

      monitor_scene

      stop_actors
    end

    # Stop the scene and all actors
    def cut!
      @running = false
      puts "\n[DIRECTOR: CUT! Scene ended.]"
    end

    # Save the transcript to a file
    #
    # @param filename [String] Output filename
    def save_transcript(filename = nil)
      filename ||= "transcript_scene_#{@scene_info[:scene_number]}_#{Time.now.to_i}.txt"

      File.open(filename, "w") do |file|
        file.puts "SCENE #{@scene_info[:scene_number]}: #{@scene_info[:scene_name]}"
        file.puts "Location: #{@scene_info[:location]}"
        file.puts "Week: #{@scene_info[:week]}"
        file.puts "\n" + "-" * 60 + "\n"

        @transcript.each do |entry|
          case entry[:type]
          when :dialog
            file.puts "#{entry[:character]}: #{entry[:line]}"
          when :stage_direction
            file.puts "[#{entry[:character].upcase} #{entry[:action]}]"
          when :beat
            file.puts "\n--- #{entry[:content]} ---\n"
          end
        end
      end

      puts "Transcript saved to: #{filename}"
      filename
    end

    # Get scene statistics
    def statistics
      total_lines = @transcript.count { |e| e[:type] == :dialog }
      lines_by_character = @transcript
        .select { |e| e[:type] == :dialog }
        .group_by { |e| e[:character] }
        .transform_values(&:count)

      {
        total_lines: total_lines,
        lines_by_character: lines_by_character,
        duration: @transcript.last&.dig(:timestamp).to_i - @transcript.first&.dig(:timestamp).to_i,
        scene: @scene_info[:scene_number],
      }
    end

    private

    def detect_character_dir(scene_file)
      scene_path = File.expand_path(scene_file)
      scene_dir = File.dirname(scene_path)

      if scene_dir =~ %r{projects/([^/]+)/scenes}
        project_name = $1
        character_dir = File.join("projects", project_name, "characters")

        if Dir.exist?(character_dir)
          debug_me("Auto-detected character directory") { character_dir }
          return character_dir
        end
      end

      character_dir = File.join(scene_dir, "..", "characters")
      if Dir.exist?(character_dir)
        debug_me("Found character directory relative to scene") { character_dir }
        return File.expand_path(character_dir)
      end

      debug_me("Using default character directory") { "characters" }
      "characters"
    end

    def load_scene
      unless File.exist?(@scene_file)
        raise "Scene file not found: #{@scene_file}"
      end

      scene = YAML.load_file(@scene_file)
      scene.transform_keys(&:to_sym)
    end

    def create_actors
      puts "\n[DIRECTOR: Calling actors to the stage...]\n"

      @bus.add_channel(:scene)

      @scene_info[:characters].each do |character_name|
        character_file = File.join(@character_dir, "#{character_name.downcase}.yml")

        unless File.exist?(character_file)
          puts "Warning: Character file not found: #{character_file}"
          next
        end

        puts "  - #{character_name} is taking their position..."

        character_data = YAML.load_file(character_file)
        character_info = character_data.transform_keys(&:to_sym)

        actor = Actor.new(
          character_info: character_info,
          scene_info: @scene_info,
          bus: @bus
        )

        @actors << actor
      end

      puts "\n[DIRECTOR: All actors ready!]\n"
    end

    def stop_actors
      puts "\n[DIRECTOR: Dismissing actors...]\n"

      @actors.each do |actor|
        actor.disconnect
        puts "  - #{actor.character_name} has left the stage"
      end

      @bus.close_all
      @actors.clear
    end

    def subscribe_to_scene
      @bus.subscribe(:scene) do |delivery|
        message = delivery.message
        msg_content = message.respond_to?(:content) ? message.content : message

        msg_content = msg_content.transform_keys(&:to_sym) if msg_content.is_a?(Hash)

        if msg_content.is_a?(Hash) && msg_content[:from]
          @transcript << {
            type: :dialog,
            character: msg_content[:from],
            line: msg_content[:content],
            timestamp: Time.now.to_i,
            emotion: msg_content[:emotion],
          }

          emotion_tag = msg_content[:emotion] ? " [#{msg_content[:emotion]}]" : ""
          puts "#{msg_content[:from]}#{emotion_tag}: #{msg_content[:content]}"
        end

        delivery.ack!
      end
    end

    def initiate_scene
      return if @actors.empty?

      first_actor = @actors.first
      debug_me("Initiating scene with #{first_actor.character_name}")

      dialog = first_actor.generate_dialog
      first_actor.speak(dialog)
    end

    def monitor_scene
      puts "\n[SCENE BEGINS]\n\n"

      timeout = WritersRoom.config.scene.timeout rescue 300
      start_time = Time.now

      while @running
        line_count = @transcript.count { |e| e[:type] == :dialog }

        if line_count >= @max_lines
          puts "\n[DIRECTOR: Maximum lines reached]"
          cut!
          break
        end

        if (Time.now - start_time) > timeout
          puts "\n[DIRECTOR: Scene timeout reached]"
          cut!
          break
        end

        sleep 0.5
      end
    end
  end
end
