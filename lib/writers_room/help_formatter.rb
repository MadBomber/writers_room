# frozen_string_literal: true

module WritersRoom
  # Formats comprehensive help output for the CLI
  class HelpFormatter
    COLORS = {
      header: "\e[1;36m",    # Cyan bold
      command: "\e[1;32m",   # Green bold
      option: "\e[1;33m",    # Yellow bold
      description: "\e[0;37m", # White
      section: "\e[1;35m",   # Magenta bold
      reset: "\e[0m"
    }.freeze

    def self.print_comprehensive_help
      new.print_comprehensive_help
    end

    def print_comprehensive_help
      print_header
      print_usage
      print_global_options
      print_commands
      print_examples
      print_footer
    end

    private

    def print_header
      puts color(:header, "=" * 80)
      puts color(:header, "WRITERSROOM - AI-Powered Creative Writing Toolkit")
      puts color(:header, "=" * 80)
      puts ""
    end

    def print_usage
      puts color(:section, "USAGE:")
      puts "  #{color(:command, 'wr')} #{color(:description, '(start interactive writing session)')}"
      puts "  #{color(:command, 'wr')} #{color(:option, '[GLOBAL_OPTIONS]')} #{color(:command, 'COMMAND')} #{color(:option, '[OPTIONS]')} #{color(:description, '[ARGS]')}"
      puts ""
    end

    def print_global_options
      puts color(:section, "GLOBAL OPTIONS:")
      puts "  #{color(:option, '--help, -h')}      #{color(:description, 'Show this help message')}"
      puts "  #{color(:option, '--version, -v')}   #{color(:description, 'Show version information')}"
      puts ""
    end

    def print_commands
      puts color(:section, "COMMANDS:")
      puts ""

      # Core Commands
      print_section_header("Core Commands")

      print_command("(bare wr)", "Start context-aware interactive writing session")
      puts ""

      print_command("init PROJECT", "Initialize a new WritersRoom project")
      print_option("--medium TYPE", "Medium: dialog, novel, novella, short_story, screenplay, etc.", indent: 4)
      print_option("-c, --concept TEXT", "Project concept/summary", indent: 4)
      print_option("-p, --provider PROVIDER", "LLM provider (ollama, openai, anthropic)", indent: 4)
      print_option("-m, --model MODEL", "Model name to use", indent: 4)
      print_option("--source-material PATH", "Path to source material", indent: 4)
      puts ""

      print_command("status", "Show project state and next steps")
      puts ""

      print_command("config", "Show current project configuration")
      puts ""

      # Writer Commands
      print_section_header("Writer Commands")

      print_command("write", "Writer tools for story development")
      puts ""

      print_subcommand("write develop-concept", "Develop project concept into fuller description")
      print_subcommand("write develop-character", "Create detailed character profile")
      print_subcommand("write create-arc", "Create a story arc outline")
      print_subcommand("write breakdown-scenes", "Break down arc into scene suggestions")
      print_subcommand("write list-arcs", "List all story arcs")
      puts ""

      # Element Commands
      print_section_header("Element Commands (universal)")

      print_command("character", "Manage characters (create, list, show, version, status)")
      print_command("scene", "Manage scenes")
      print_command("arc", "Manage story arcs")
      print_command("location", "Manage locations")
      print_command("setting", "Manage settings")
      print_command("relationship", "Manage relationships")
      print_command("theme", "Manage themes")
      print_command("chapter", "Manage chapters (novel/novella)")
      puts ""

      print_subcommand("<type> create NAME", "Create a new element")
      print_subcommand("<type> list", "List all elements of this type")
      print_subcommand("<type> show SLUG", "Show element details")
      print_subcommand("<type> version SLUG", "Create a new version")
      print_subcommand("<type> status SLUG STATUS", "Update element status")
      puts ""

      # Story Bible
      print_section_header("Story Bible")

      print_command("bible", "Story bible management")
      puts ""

      print_subcommand("bible regenerate", "Rebuild the story bible index")
      print_subcommand("bible show", "Display the story bible")
      print_subcommand("bible search TERM", "Search the story bible")
      puts ""

      # Export
      print_section_header("Export")

      print_command("export", "Export project content")
      puts ""

      print_subcommand("export manuscript", "Export formatted manuscript")
      print_option("-o, --output FILE", "Output file path", indent: 6)
      print_subcommand("export bible", "Export story bible document")
      print_subcommand("export references", "Export cross-reference graph")
      puts ""

      # Production Commands (Dialog)
      print_section_header("Production Commands (Dialog)")

      print_command("direct SCENE_FILE", "Direct a scene with in-process actors")
      print_option("-o, --output FILE", "Transcript output file", indent: 4)
      print_option("-l, --max-lines N", "Maximum lines before ending (default: 50)", indent: 4)
      puts ""

      print_command("produce [SCENES...]", "Run a full production")
      print_option("--chat", "Interactive chat mode to plan production", indent: 4)
      puts ""

      print_command("report", "Generate production report from transcripts")
      puts ""

      # Utility Commands
      print_section_header("Utility Commands")

      print_command("version", "Show WritersRoom version")
      print_command("help [COMMAND]", "Show help for a specific command")
      print_option("--verbose", "Show this comprehensive help", indent: 4)
      puts ""
    end

    def print_examples
      puts color(:section, "EXAMPLES:")
      puts ""

      puts color(:description, "  # Start an interactive writing session")
      puts "  #{color(:command, 'wr')}"
      puts ""

      puts color(:description, "  # Initialize a novel project")
      puts "  #{color(:command, 'wr init')} my_novel #{color(:option, '--medium')} novel #{color(:option, '-c')} \"A coming-of-age story\""
      puts ""

      puts color(:description, "  # Initialize a dialog project (default)")
      puts "  #{color(:command, 'wr init')} my_show #{color(:option, '-c')} \"A story about two friends\""
      puts ""

      puts color(:description, "  # Check project status and next steps")
      puts "  #{color(:command, 'wr status')}"
      puts ""

      puts color(:description, "  # Create a character")
      puts "  #{color(:command, 'wr character create')} Alice"
      puts ""

      puts color(:description, "  # Create a chapter (novel projects)")
      puts "  #{color(:command, 'wr chapter create')} \"The Beginning\""
      puts ""

      puts color(:description, "  # Export manuscript")
      puts "  #{color(:command, 'wr export manuscript')} #{color(:option, '-o')} my_novel.md"
      puts ""

      puts color(:description, "  # View story bible")
      puts "  #{color(:command, 'wr bible show')}"
      puts ""

      puts color(:description, "  # Direct a dialog scene")
      puts "  #{color(:command, 'wr direct')} scenes/coffee_shop.md #{color(:option, '-l')} 30"
      puts ""
    end

    def print_footer
      puts color(:section, "WORKFLOW:")
      puts ""
      puts color(:description, "  1. wr init <project> --medium novel -c \"concept\"")
      puts color(:description, "  2. cd <project>")
      puts color(:description, "  3. wr                           (start interactive chat)")
      puts color(:description, "  4. wr status                    (check progress)")
      puts color(:description, "  5. wr character create <name>   (create characters)")
      puts color(:description, "  6. wr chapter create <name>     (outline chapters)")
      puts color(:description, "  7. wr bible regenerate           (update story bible)")
      puts color(:description, "  8. wr export manuscript          (export your work)")
      puts ""

      puts color(:section, "SUPPORTED MEDIA:")
      puts "  dialog, novel, novella, short_story, screenplay,"
      puts "  stage_play, tv_series, radio_play, documentary"
      puts ""

      puts color(:section, "CONFIGURATION:")
      puts "  Default LLM: Ollama with gpt-oss model"
      puts "  Override with environment variables:"
      puts "    WRITERS_ROOM_PROVIDER=openai"
      puts "    WRITERS_ROOM_MODEL_NAME=gpt-4"
      puts ""

      puts color(:header, "=" * 80)
      puts color(:header, "For command-specific help: wr help [COMMAND]")
      puts color(:header, "For more info: https://github.com/madbomber/writers_room")
      puts color(:header, "=" * 80)
      puts ""
    end

    def print_section_header(title)
      puts color(:section, "  #{title}:")
      puts color(:section, "  " + "-" * (title.length + 1))
    end

    def print_command(name, description)
      puts "  #{color(:command, name.ljust(20))} #{color(:description, description)}"
    end

    def print_subcommand(name, description)
      puts "    #{color(:command, name.ljust(34))} #{color(:description, description)}"
    end

    def print_option(option, description, indent: 4)
      spaces = " " * indent
      puts "#{spaces}#{color(:option, option.ljust(40 - indent))} #{color(:description, description)}"
    end

    def color(type, text)
      return text unless STDOUT.tty?
      "#{COLORS[type]}#{text}#{COLORS[:reset]}"
    end
  end
end
