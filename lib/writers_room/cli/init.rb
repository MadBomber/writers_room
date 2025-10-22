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
                    default: "gpt-oss:20b",
                    desc: "Model name to use"
      method_option :concept,
                    aliases: "-c",
                    type: :string,
                    default: "",
                    desc: "Project concept/summary"

      def init(project_name)
        require_relative "../producer"

        project_path = File.join(Dir.pwd, project_name)

        if File.exist?(project_path)
          say "Error: Directory '#{project_name}' already exists!", :red
          exit 1
        end

        say "Creating WritersRoom project: #{project_name}", :green

        # Create project with configuration and metadata
        producer = WritersRoom::Producer.create_project(
          project_path,
          name: project_name,
          concept: options[:concept],
          provider: options[:provider],
          model_name: options[:model]
        )

        say "✓ Created project directory: #{project_path}", :green
        say "✓ Created configuration: config.yml", :green
        say "✓ Created project metadata: project.yml", :green
        say "✓ Created directories: characters, scenes, transcripts, logs", :green
        say "", :green
        say "Configuration:", :cyan
        say "  Provider:   #{producer.config.provider}", :white
        say "  Model:      #{producer.config.model_name}", :white

        if options[:concept] && !options[:concept].empty?
          say ""
          say "Concept:", :cyan
          say "  #{producer.metadata.concept}", :white
        end

        say "", :green
        say "Your WritersRoom project is ready! 🎭", :green
        say ""
        say "Next steps:", :cyan
        say "  1. cd #{project_name}", :white
        say "  2. Use 'wr write develop-concept' to expand your concept", :white
        say "  3. Use 'wr write develop-character' to create character profiles", :white
        say "  4. Use 'wr write create-arc' to plan your story structure", :white
      rescue StandardError => e
        say "Error initializing project: #{e.message}", :red
        say e.backtrace.join("\n"), :red if ENV["DEBUG"]
        exit 1
      end
    end
  end
end
