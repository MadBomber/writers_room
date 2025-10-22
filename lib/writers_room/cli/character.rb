# frozen_string_literal: true

require "thor"

module WritersRoom
  module Commands
    class Character < Thor
      desc "create NAME", "Create a new character"
      method_option :personality,
                    aliases: "-p",
                    type: :string,
                    default: "neutral",
                    desc: "Character personality"
      method_option :speaking_style,
                    aliases: "-s",
                    type: :string,
                    default: "conversational",
                    desc: "Character speaking style"
      method_option :background,
                    aliases: "-b",
                    type: :string,
                    default: "",
                    desc: "Character background"

      def create(name)
        require_relative "../producer"

        producer = WritersRoom::Producer.new

        traits = {
          personality: options[:personality],
          speaking_style: options[:speaking_style],
          background: options[:background]
        }

        character_file = producer.create_character(name, traits)
        say "Created character: #{character_file}", :green
      rescue WritersRoom::Error => e
        say "Error: #{e.message}", :red
        exit 1
      rescue StandardError => e
        say "Error creating character: #{e.message}", :red
        say e.backtrace.join("\n"), :red if ENV["DEBUG"]
        exit 1
      end

      desc "list", "List all characters in the project"
      def list
        require_relative "../producer"

        producer = WritersRoom::Producer.new
        characters = producer.list_characters

        if characters.empty?
          say "No characters found in characters/ directory", :yellow
          exit 0
        end

        say "Characters:", :cyan
        characters.each do |char|
          say "  #{char[:name]}", :white
          say "    File: #{File.basename(char[:file])}", :white
          say "    Personality: #{char[:personality]}", :white
          say ""
        end
      rescue WritersRoom::Error => e
        say "Error: #{e.message}", :red
        exit 1
      rescue StandardError => e
        say "Error listing characters: #{e.message}", :red
        say e.backtrace.join("\n"), :red if ENV["DEBUG"]
        exit 1
      end
    end
  end
end
