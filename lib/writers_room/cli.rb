# frozen_string_literal: true

require "thor"
require "writers_room"

module WritersRoom
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    # Show help when no command is given
    default_task :help

    desc "version", "Show WritersRoom version"
    def version
      require_relative "cli/version"
      Commands::Version.new.version
    end

    desc "init PROJECT_NAME", "Initialize a new WritersRoom project"
    method_option :provider,
                  aliases: "-p",
                  type: :string,
                  default: "ollama",
                  desc: "LLM provider (ollama, openai, anthropic, etc.)"
    method_option :model,
                  aliases: "-m",
                  type: :string,
                  default: "gpt-oss",
                  desc: "Model name to use"
    def init(project_name)
      require_relative "cli/init"
      Commands::Init.new([], options).init(project_name)
    end

    desc "config", "Show current configuration"
    def config
      require_relative "cli/config"
      Commands::Config.new.config
    end

    desc "actor CHARACTER_FILE SCENE_FILE", "Run a single actor"
    method_option :channel,
                  aliases: "-r",
                  type: :string,
                  default: "writers_room:dialog",
                  desc: "Redis channel"
    def actor(character_file, scene_file)
      require_relative "cli/actor"
      Commands::Actor.new([], options).actor(character_file, scene_file)
    end

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
      require_relative "cli/direct"
      Commands::Direct.new([], options).direct(scene_file)
    end
  end
end
