# frozen_string_literal: true

require "thor"

module WritersRoom
  module Commands
    class Produce < Thor
      desc "produce [SCENE_FILES...]", "Run a full production (all scenes or specific scenes)"
      method_option :max_lines,
                    aliases: "-l",
                    type: :numeric,
                    default: 50,
                    desc: "Maximum lines per scene before ending"
      method_option :output,
                    aliases: "-o",
                    type: :string,
                    desc: "Transcript output directory"
      method_option :chat,
                    type: :boolean,
                    default: false,
                    desc: "Interactive chat mode to plan production"

      def produce(*scene_files)
        require_relative "../producer"

        producer = WritersRoom::Producer.new

        # Handle graceful shutdown
        trap("INT") do
          say "\n[PRODUCER: Production interrupted]", :yellow
          exit 0
        end

        # Validate project structure
        begin
          producer.validate_project
        rescue WritersRoom::Error => e
          say "Error: #{e.message}", :red
          exit 1
        end

        # Use all scenes if none specified
        if scene_files.empty?
          scene_files = Dir.glob(File.join(Dir.pwd, "scenes", "*.yml"))
          if scene_files.empty?
            say "No scene files found in scenes/ directory", :yellow
            exit 1
          end
        else
          # Convert relative paths to absolute
          scene_files = scene_files.map { |f| File.expand_path(f) }
        end

        # If chat mode, discuss production planning before running
        if options[:chat]
          say "Starting interactive chat about production planning...", :cyan
          say ""
          result = producer.chat_about_production(scene_files)

          say "\n" + "=" * 60, :green
          say "CHAT SESSION COMPLETE", :green
          say "=" * 60, :green
          say ""
          say "Summary:", :cyan
          say result[:summary], :white
          say ""
          say "Chat saved to: #{result[:chat_log]}", :yellow
          say ""
          say "Would you like to proceed with production? (y/n)", :cyan
          response = STDIN.gets&.chomp&.downcase

          unless %w[y yes].include?(response)
            say "Production cancelled.", :yellow
            exit 0
          end
        end

        say "=" * 60, :cyan
        say "STARTING PRODUCTION", :cyan
        say "=" * 60, :cyan
        say "Scenes to produce: #{scene_files.count}", :white
        scene_files.each { |f| say "  - #{File.basename(f)}", :white }
        say ""

        # Run production
        results = producer.produce(scene_files, options.transform_keys(&:to_sym))

        # Show results
        say "\n" + "=" * 60, :cyan
        say "PRODUCTION COMPLETE", :cyan
        say "=" * 60, :cyan

        successful = results.select { |r| r[:status] == :completed }
        failed = results.select { |r| r[:status] == :failed }

        say "Completed: #{successful.count}", :green
        say "Failed: #{failed.count}", :red if failed.any?

        successful.each do |result|
          say "\n#{File.basename(result[:scene])}:", :cyan
          say "  Transcript: #{result[:transcript]}", :white
          say "  Lines: #{result[:statistics][:total_lines]}", :white
        end

        if failed.any?
          say "\nFailed scenes:", :red
          failed.each do |result|
            say "  #{File.basename(result[:scene])}: #{result[:error]}", :red
          end
        end
      rescue WritersRoom::Error => e
        say "Error: #{e.message}", :red
        exit 1
      rescue StandardError => e
        say "Error running production: #{e.message}", :red
        say e.backtrace.join("\n"), :red if ENV["DEBUG"]
        exit 1
      end
    end
  end
end
