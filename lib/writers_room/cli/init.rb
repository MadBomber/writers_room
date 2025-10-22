# frozen_string_literal: true

require "thor"

module WritersRoom
  module Commands
    class Init < Thor
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
        project_path = File.join(Dir.pwd, project_name)

        if File.exist?(project_path)
          say "Error: Directory '#{project_name}' already exists!", :red
          exit 1
        end

        say "Creating WritersRoom project: #{project_name}", :green

        config_options = {
          provider: options[:provider],
          model_name: options[:model]
        }

        config = Config.create_project(project_path, config_options)

        say "✓ Created project directory: #{project_path}", :green
        say "✓ Created configuration file: #{config.path}", :green
        say "", :green
        say "Configuration:", :cyan
        say "  Provider:   #{config.provider}", :white
        say "  Model:      #{config.model_name}", :white
        say "", :green
        say "Your WritersRoom project is ready! 🎭", :green
      rescue StandardError => e
        say "Error initializing project: #{e.message}", :red
        exit 1
      end
    end
  end
end
