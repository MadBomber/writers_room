# frozen_string_literal: true

require "thor"
require "yaml"

module WritersRoom
  module Commands
    class Actor < Thor
      desc "actor CHARACTER_FILE SCENE_FILE", "Run a single actor"
      method_option :channel,
                    aliases: "-r",
                    type: :string,
                    default: "writers_room:dialog",
                    desc: "Redis channel"

      def actor(character_file, scene_file)
        require_relative "../actor"

        unless File.exist?(character_file)
          say "Error: Character file not found: #{character_file}", :red
          exit 1
        end

        unless File.exist?(scene_file)
          say "Error: Scene file not found: #{scene_file}", :red
          exit 1
        end

        # Load character and scene info
        character_info = YAML.load_file(character_file)
        scene_info = YAML.load_file(scene_file)

        # Create and start the actor
        actor = WritersRoom::Actor.new(character_info)
        actor.set_scene(scene_info)

        say "#{actor.character_name} entering scene: #{scene_info[:scene_name]}", :green
        say "Listening on channel: #{options[:channel]}", :cyan
        say "Press Ctrl+C to exit", :yellow

        # Handle graceful shutdown
        trap("INT") do
          say "\n#{actor.character_name} exiting scene...", :yellow
          actor.stop
          exit 0
        end

        # Start performing
        actor.perform(channel: options[:channel])
      rescue StandardError => e
        say "Error running actor: #{e.message}", :red
        say e.backtrace.join("\n"), :red if ENV["DEBUG"]
        exit 1
      end
    end
  end
end
