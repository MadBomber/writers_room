# frozen_string_literal: true
##########################################################
###
##  File: director.rb
##  Desc: Director to orchestrate multiple actors in a scene
##  By:   Dewayne VanHoozer (dvanhoozer@gmail.com)
#

require "yaml"

module WritersRoom
  # Director orchestrates a scene using the Room pattern.
  #
  # Instead of manual sleep-polling, the Director:
  # - Creates a Room (bus + memory + roster)
  # - Loads actors from .md character files
  # - Seeds the scene with an opening prompt
  # - Lets Room.wait_for_completion handle the event loop
  # - Assembles transcript from shared memory
  class Director
    attr_reader :scene_info, :transcript, :room

    # Initialize the Director.
    #
    # @param scene_file [String] Path to scene .md file
    # @param character_dir [String] Directory containing character files (optional, auto-detected)
    # @param max_lines [Integer] Maximum dialog lines before scene ends
    def initialize(scene_file:, character_dir: nil, max_lines: nil)
      @scene_file = scene_file
      @character_dir = character_dir || detect_character_dir(scene_file)
      @scene_info = load_scene
      @max_lines = max_lines || ENV["MAX_LINES"]&.to_i || 50
      @transcript = []
      @running = false

      # Build shared config via LLMSetup
      @run_config = LLMSetup.build_run_config

      # Create display
      @display = Display.new

      # Create room
      @room = Room.new(
        display:    @display,
        config:     @run_config,
        scene_info: @scene_info
      )

    end

    # Start the scene with all actors.
    def action!
      @display.scene_header(@scene_info)
      @running = true

      load_actors
      seed_scene
      @room.wait_for_completion(timeout: scene_timeout, max_lines: @max_lines)

      # Collect transcript from shared memory
      @transcript = @room.assemble_transcript

      shutdown_actors
    end

    # Stop the scene and all actors.
    def cut!
      @running = false
      @display.director_note("CUT! Scene ended.")
      shutdown_actors
    end

    # Save the transcript to a file.
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
          emotion_tag = entry[:emotion] ? " [#{entry[:emotion]}]" : ""
          file.puts "#{entry[:from]}#{emotion_tag}: #{entry[:content]}"
        end
      end

      @display.info("Transcript saved to: #{filename}")
      filename
    end

    # Get scene statistics.
    def statistics
      total_lines = @transcript.length
      lines_by_character = @transcript
        .group_by { |e| e[:from] }
        .transform_values(&:count)

      {
        total_lines: total_lines,
        lines_by_character: lines_by_character,
        scene: @scene_info[:scene_number],
      }
    end

    private

    def scene_timeout
      WritersRoom.config.scene.timeout rescue 300
    end

    def detect_character_dir(scene_file)
      scene_path = File.expand_path(scene_file)
      scene_dir = File.dirname(scene_path)

      if scene_dir =~ %r{projects/([^/]+)/scenes}
        project_name = $1
        character_dir = File.join("projects", project_name, "characters")

        if Dir.exist?(character_dir)
          return character_dir
        end
      end

      character_dir = File.join(scene_dir, "..", "characters")
      if Dir.exist?(character_dir)
        return File.expand_path(character_dir)
      end

      "characters"
    end

    # Load scene file (.md with front matter).
    def load_scene
      unless File.exist?(@scene_file)
        raise "Scene file not found: #{@scene_file}"
      end

      parsed = FrontMatter.load_file(@scene_file)
      scene = parsed[:metadata]
      scene[:body] = parsed[:body]
      scene
    end

    # Load actors from character files into the Room.
    def load_actors
      @display.director_note("Calling actors to the stage...")

      characters = @scene_info[:characters] || []
      characters.each do |character_name|
        character_info = load_character(character_name)

        unless character_info
          @display.info("  Warning: Character file not found for: #{character_name}")
          next
        end

        @display.info("  - #{character_name} is taking their position...")
        @room.add_actor(character_name, character_info: character_info)
      end

      @display.director_note("All actors ready!")
    end

    # Load a character file (.md with front matter).
    def load_character(character_name)
      slug = character_name.downcase.gsub(/\s+/, "_")
      md_file = File.join(@character_dir, "#{slug}.md")

      return nil unless File.exist?(md_file)

      parsed = FrontMatter.load_file(md_file)
      info = parsed[:metadata]
      info[:body] = parsed[:body]
      info
    end

    # Seed the scene with the opening context.
    def seed_scene
      @display.director_note("SCENE BEGINS")

      opening = build_opening_prompt
      @room.seed(opening)
    end

    # Build the opening prompt from scene info.
    def build_opening_prompt
      context = @scene_info[:body] || ""
      characters = Array(@scene_info[:characters]).join(", ")

      <<~PROMPT
        [DIRECTOR] Scene #{@scene_info[:scene_number]}: #{@scene_info[:scene_name]}
        Location: #{@scene_info[:location]}
        Characters present: #{characters}

        #{context}

        The scene begins now. Stay in character and use the speak tool to deliver your dialog.
      PROMPT
    end

    def shutdown_actors
      @room&.shutdown
    end
  end
end
