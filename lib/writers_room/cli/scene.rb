# frozen_string_literal: true

require "thor"

module WritersRoom
  module Commands
    class Scene < Thor
      desc "create NAME", "Create a new scene"
      method_option :description,
                    aliases: "-d",
                    type: :string,
                    default: "",
                    desc: "Scene description"
      method_option :characters,
                    aliases: "-c",
                    type: :array,
                    default: [],
                    desc: "Character names for the scene"

      def create(name)
        require_relative "../producer"

        producer = WritersRoom::Producer.new

        scene_file = producer.create_scene(
          name,
          options[:description],
          options[:characters]
        )

        say "Created scene: #{scene_file}", :green
        say "Characters: #{options[:characters].join(', ')}", :white if options[:characters].any?
      rescue WritersRoom::Error => e
        say "Error: #{e.message}", :red
        exit 1
      rescue StandardError => e
        say "Error creating scene: #{e.message}", :red
        say e.backtrace.join("\n"), :red if ENV["DEBUG"]
        exit 1
      end

      desc "list", "List all scenes in the project"
      def list
        require_relative "../producer"

        producer = WritersRoom::Producer.new
        scenes = producer.list_scenes

        if scenes.empty?
          say "No scenes found in scenes/ directory", :yellow
          exit 0
        end

        say "Scenes:", :cyan
        scenes.each do |scene|
          say "  #{scene[:name]}", :white
          say "    File: #{File.basename(scene[:file])}", :white
          say "    Characters: #{scene[:characters].join(', ')}", :white if scene[:characters].any?
          say ""
        end
      rescue WritersRoom::Error => e
        say "Error: #{e.message}", :red
        exit 1
      rescue StandardError => e
        say "Error listing scenes: #{e.message}", :red
        say e.backtrace.join("\n"), :red if ENV["DEBUG"]
        exit 1
      end
    end
  end
end
