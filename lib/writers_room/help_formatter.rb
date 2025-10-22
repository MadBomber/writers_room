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
      puts color(:header, "WRITERSROOM - AI-Powered Multi-Agent Story Development")
      puts color(:header, "=" * 80)
      puts ""
    end

    def print_usage
      puts color(:section, "USAGE:")
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

      # Producer Commands
      print_section_header("Producer Commands")

      print_command("init", "Initialize a new WritersRoom project")
      print_option("-p, --provider PROVIDER", "LLM provider (ollama, openai, anthropic)", indent: 4)
      print_option("-m, --model MODEL", "Model name to use (default: gpt-oss)", indent: 4)
      print_option("-c, --concept CONCEPT", "Project concept/summary", indent: 4)
      puts ""

      print_command("config", "Show current project configuration")
      puts ""

      print_command("produce", "Run a full production (all scenes or specific scenes)")
      print_option("[SCENE_FILES...]", "Optional list of scene files to produce", indent: 4)
      print_option("-l, --max-lines N", "Maximum lines per scene (default: 50)", indent: 4)
      print_option("-o, --output DIR", "Transcript output directory", indent: 4)
      print_option("--chat", "Interactive chat mode to plan production", indent: 4)
      puts ""

      print_command("report", "Generate production report from all transcripts")
      puts ""

      # Writer Commands
      print_section_header("Writer Commands")

      print_command("write", "Writer tools for story development")
      puts ""

      print_subcommand("write develop-concept", "Develop project concept into fuller description")
      print_option("--chat", "Interactive chat mode with LLM", indent: 6)
      puts ""

      print_subcommand("write develop-character", "Create detailed character profile")
      print_option("NAME", "Character name (required)", indent: 6)
      print_option("-p, --personality TEXT", "Basic personality description", indent: 6)
      print_option("-b, --background TEXT", "Background notes", indent: 6)
      print_option("--chat", "Interactive chat mode with LLM", indent: 6)
      puts ""

      print_subcommand("write create-arc", "Create a story arc outline")
      print_option("NAME", "Arc name (required)", indent: 6)
      print_option("-d, --description TEXT", "Arc description (required)", indent: 6)
      print_option("--chat", "Interactive chat mode with LLM", indent: 6)
      puts ""

      print_subcommand("write breakdown-scenes", "Break down arc into scene suggestions")
      print_option("ARC_NAME", "Name of arc to breakdown (required)", indent: 6)
      print_option("-n, --num-scenes N", "Number of scenes to generate (default: 5)", indent: 6)
      print_option("--chat", "Interactive chat mode with LLM", indent: 6)
      puts ""

      print_subcommand("write list-arcs", "List all story arcs in the project")
      puts ""

      # Character Commands
      print_section_header("Character Commands")

      print_command("character", "Manage characters")
      puts ""

      print_subcommand("character create", "Create a new character")
      print_option("NAME", "Character name (required)", indent: 6)
      print_option("-p, --personality TEXT", "Personality trait", indent: 6)
      print_option("-s, --speaking-style TEXT", "Speaking style", indent: 6)
      print_option("-b, --background TEXT", "Background information", indent: 6)
      puts ""

      print_subcommand("character list", "List all characters in the project")
      puts ""

      # Scene Commands
      print_section_header("Scene Commands")

      print_command("scene", "Manage scenes")
      puts ""

      print_subcommand("scene create", "Create a new scene")
      print_option("NAME", "Scene name (required)", indent: 6)
      print_option("-d, --description TEXT", "Scene description", indent: 6)
      print_option("-c, --characters CHAR1 CHAR2", "Characters in scene", indent: 6)
      puts ""

      print_subcommand("scene list", "List all scenes in the project")
      puts ""

      # Director Commands
      print_section_header("Director Commands")

      print_command("direct", "Direct a scene with multiple actors")
      print_option("SCENE_FILE", "Scene YAML file (required)", indent: 4)
      print_option("-c, --characters DIR", "Character directory (auto-detected)", indent: 4)
      print_option("-o, --output FILE", "Transcript output file", indent: 4)
      print_option("-l, --max-lines N", "Maximum lines before ending (default: 50)", indent: 4)
      puts ""

      # Actor Commands
      print_section_header("Actor Commands (Advanced)")

      print_command("actor", "Run a single actor process")
      print_option("CHARACTER_FILE", "Character YAML file (required)", indent: 4)
      print_option("SCENE_FILE", "Scene YAML file (required)", indent: 4)
      print_option("-r, --channel CHANNEL", "Redis channel (default: writers_room:dialog)", indent: 4)
      puts ""

      # Utility Commands
      print_section_header("Utility Commands")

      print_command("version", "Show WritersRoom version")
      puts ""

      print_command("help", "Show help information")
      print_option("[COMMAND]", "Show help for specific command", indent: 4)
      print_option("--verbose", "Show comprehensive help (this output)", indent: 4)
      puts ""
    end

    def print_examples
      puts color(:section, "EXAMPLES:")
      puts ""

      puts color(:description, "  # Initialize a new project")
      puts "  #{color(:command, 'wr init')} my_show #{color(:option, '-c')} \"A story about two friends\""
      puts ""

      puts color(:description, "  # Develop project concept with interactive chat")
      puts "  #{color(:command, 'wr write develop-concept')} #{color(:option, '--chat')}"
      puts ""

      puts color(:description, "  # Create a character with chat assistance")
      puts "  #{color(:command, 'wr write develop-character')} Alice #{color(:option, '-p')} cheerful #{color(:option, '--chat')}"
      puts ""

      puts color(:description, "  # Create story arc")
      puts "  #{color(:command, 'wr write create-arc')} \"Act 1\" #{color(:option, '-d')} \"The setup and introduction\""
      puts ""

      puts color(:description, "  # Break down arc into scenes")
      puts "  #{color(:command, 'wr write breakdown-scenes')} \"Act 1\" #{color(:option, '-n')} 5"
      puts ""

      puts color(:description, "  # Create actual character file")
      puts "  #{color(:command, 'wr character create')} Alice #{color(:option, '-p')} cheerful #{color(:option, '-s')} casual"
      puts ""

      puts color(:description, "  # Create a scene")
      puts "  #{color(:command, 'wr scene create')} \"Coffee Shop\" #{color(:option, '-d')} \"First meeting\" #{color(:option, '-c')} Alice Bob"
      puts ""

      puts color(:description, "  # Direct a scene")
      puts "  #{color(:command, 'wr direct')} scenes/coffee_shop.yml #{color(:option, '-l')} 30"
      puts ""

      puts color(:description, "  # Run full production with chat planning")
      puts "  #{color(:command, 'wr produce')} #{color(:option, '--chat')}"
      puts ""

      puts color(:description, "  # Generate report")
      puts "  #{color(:command, 'wr report')}"
      puts ""
    end

    def print_footer
      puts color(:section, "WORKFLOW:")
      puts ""
      puts color(:description, "  1. Producer:  wr init <project> -c \"concept\"")
      puts color(:description, "  2. Producer:  cd <project>")
      puts color(:description, "  3. Writer:    wr write develop-concept --chat")
      puts color(:description, "  4. Writer:    wr write develop-character <name> --chat")
      puts color(:description, "  5. Writer:    wr write create-arc <name> -d \"description\"")
      puts color(:description, "  6. Writer:    wr write breakdown-scenes <arc>")
      puts color(:description, "  7. Producer:  wr character create <name>")
      puts color(:description, "  8. Producer:  wr scene create <name>")
      puts color(:description, "  9. Director:  wr direct <scene_file>")
      puts color(:description, " 10. Producer:  wr produce")
      puts color(:description, " 11. Producer:  wr report")
      puts ""

      puts color(:section, "DOCUMENTATION:")
      puts "  See WORKFLOW.md for complete workflow guide"
      puts "  See CHAT_FEATURE.md for interactive chat mode details"
      puts "  See completions/INSTALL.md for shell completion setup"
      puts ""

      puts color(:section, "CONFIGURATION:")
      puts "  Default LLM: Ollama with gpt-oss model"
      puts "  Override with environment variables:"
      puts "    RUBY_LLM_PROVIDER=openai"
      puts "    RUBY_LLM_MODEL=gpt-4"
      puts "    OLLAMA_URL=http://localhost:11434"
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
