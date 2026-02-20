# frozen_string_literal: true

require "thor"
require "writers_room"

module WritersRoom
  module Commands
    autoload :Character, "writers_room/cli/character"
    autoload :Scene, "writers_room/cli/scene"
    autoload :Write, "writers_room/cli/write"
    autoload :Bible, "writers_room/cli/bible"
    autoload :Export, "writers_room/cli/export"
  end

  class CLI < Thor
    package_name "wr"
    namespace "wr"

    # Global class options
    class_option :help,
                 type: :boolean,
                 aliases: "-h",
                 desc: "Show comprehensive help"

    class_option :version,
                 type: :boolean,
                 aliases: "-v",
                 desc: "Show version"

    def self.exit_on_failure?
      true
    end

    # Running bare `wr` starts context-aware interactive chat
    default_task :chat

    # Handle global options
    def initialize(*args)
      super

      # Handle --help
      if options[:help]
        require_relative "help_formatter"
        HelpFormatter.print_comprehensive_help
        exit 0
      end

      # Handle --version
      if options[:version]
        puts "WritersRoom #{WritersRoom::VERSION}"
        exit 0
      end
    end

    # Override Thor's help to support --verbose and --help
    desc "help [COMMAND]", "Describe available commands or one specific command"
    method_option :verbose,
                  type: :boolean,
                  default: false,
                  desc: "Show comprehensive help with all commands and options"
    def help(command = nil)
      if options[:verbose]
        require_relative "help_formatter"
        HelpFormatter.print_comprehensive_help
      elsif command
        self.class.command_help(shell, command)
      else
        super
      end
    end

    desc "chat", "Start a context-aware interactive writing session (default command)"
    def chat
      require_relative "cli/chat"
      Commands::Chat.new.chat
    end

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
                  default: "gpt-oss:20b",
                  desc: "Model name to use"
    method_option :concept,
                  aliases: "-c",
                  type: :string,
                  default: "",
                  desc: "Project concept/summary"
    method_option :medium,
                  type: :string,
                  desc: "Medium type (dialog, novel, novella, short_story, screenplay, stage_play, tv_series, radio_play, documentary)"
    method_option :source_material,
                  type: :string,
                  desc: "Path to source material (another project or files)"
    def init(project_name)
      require_relative "cli/init"
      Commands::Init.new([], options).init(project_name)
    end

    desc "config", "Show current configuration"
    def config
      require_relative "cli/config"
      Commands::Config.new.config
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
      require_relative "cli/produce"
      Commands::Produce.new([], options).produce(*scene_files)
    end

    desc "write SUBCOMMAND", "Writer tools (develop-concept, develop-character, create-arc, breakdown-scenes)"
    subcommand "write", Commands::Write

    desc "character SUBCOMMAND", "Manage characters (create, list)"
    subcommand "character", Commands::Character

    desc "scene SUBCOMMAND", "Manage scenes (create, list)"
    subcommand "scene", Commands::Scene

    desc "report", "Generate production report from all transcripts"
    def report
      require_relative "cli/report"
      Commands::Report.new.report
    end

    desc "bible SUBCOMMAND", "Story bible management (regenerate, show, search)"
    subcommand "bible", Commands::Bible

    desc "status", "Show project state and next steps"
    def status
      context = WritersRoom::ContextDetector.new.detect

      unless context.in_project?
        say "Not inside a WritersRoom project.", :yellow
        say "Run 'wr init PROJECT_NAME' to create one.", :white
        return
      end

      state = context.project_state
      say state.summary

      workflow = WritersRoom::Workflow.new(context.medium)
      steps = workflow.next_steps(context.project_path)
      if steps.any?
        say "\nNext steps:", :cyan
        steps.each { |s| say "  - #{s}", :white }
      end
    end

    desc "export SUBCOMMAND", "Export project (manuscript, bible, references)"
    subcommand "export", Commands::Export

    # Register dynamic element subcommands for common types.
    # These work for any medium -- the element command reads from the
    # appropriate directory relative to CWD or --project.
    %w[chapter arc location setting relationship theme].each do |type|
      require_relative "cli/element"
      desc "#{type} SUBCOMMAND", "Manage #{type}s (create, list, show, version, status)"
      subcommand type, Commands::Element.for_type(type)
    end
  end
end
