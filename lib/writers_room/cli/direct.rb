# frozen_string_literal: true

require "thor"
require "fileutils"

module WritersRoom
  module Commands
    class Direct < Thor
      desc "direct SCENE_FILE", "Direct a scene with multiple actors"
      method_option :characters,
                    aliases: "-c",
                    type: :string,
                    desc: "Character directory (auto-detected if not specified)"
      method_option :output,
                    aliases: "-o",
                    type: :string,
                    desc: "Transcript output file"
      method_option :max_lines,
                    aliases: "-l",
                    type: :numeric,
                    default: 50,
                    desc: "Maximum lines before ending"

      def direct(scene_file)
        require_relative "../director"

        unless File.exist?(scene_file)
          say "Error: Scene file not found: #{scene_file}", :red
          exit 1
        end

        # Set max lines environment variable
        ENV["MAX_LINES"] = options[:max_lines].to_s

        # Create logs directory if it doesn't exist
        FileUtils.mkdir_p("logs")

        # Create and run director
        director = WritersRoom::Director.new(
          scene_file: scene_file,
          character_dir: options[:characters]
        )

        # Handle graceful shutdown
        trap("INT") do
          say "\n[DIRECTOR: Interrupt received]", :yellow
          director.cut!

          # Save transcript
          filename = director.save_transcript(options[:output])

          # Show statistics
          show_statistics(director)

          exit 0
        end

        # Start the scene
        director.action!

        # Save transcript when done
        filename = director.save_transcript(options[:output])

        # Show statistics
        show_statistics(director)
      rescue StandardError => e
        say "Error directing scene: #{e.message}", :red
        say e.backtrace.join("\n"), :red if ENV["DEBUG"]
        exit 1
      end

      private

      def show_statistics(director)
        stats = director.statistics

        say "\n" + "=" * 60, :cyan
        say "SCENE STATISTICS", :cyan
        say "=" * 60, :cyan
        say "Total lines: #{stats[:total_lines]}", :white
        say "\nLines by character:", :white

        stats[:lines_by_character].sort_by { |_, count| -count }.each do |char, count|
          say "  #{char}: #{count}", :white
        end

        say "=" * 60, :cyan
      end
    end
  end
end
