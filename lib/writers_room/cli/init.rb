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
      method_option :medium,
                    type: :string,
                    desc: "Medium type (dialog, novel, novella, short_story, screenplay, stage_play, tv_series, radio_play, documentary)"

      def init(project_name)
        require_relative "../producer"

        project_path = File.join(Dir.pwd, project_name)

        if File.exist?(project_path)
          say "Error: Directory '#{project_name}' already exists!", :red
          exit 1
        end

        medium_id = options[:medium]

        if medium_id.nil? || medium_id.empty?
          medium = choose_medium
        else
          begin
            medium = WritersRoom::MediumRegistry.find(medium_id)
          rescue WritersRoom::Error
            say "Error: Unknown medium '#{medium_id}'. Available: #{WritersRoom::MediumRegistry.ids.join(', ')}", :red
            exit 1
          end
        end

        medium_id = medium.id.to_s

        say "Creating WritersRoom project: #{project_name} (#{medium.label})", :green

        # Create project config file
        config_path = File.join(project_path, "config.yml")
        FileUtils.mkdir_p(project_path)

        config_data = {
          "provider" => options[:provider],
          "model_name" => options[:model]
        }
        File.write(config_path, YAML.dump(config_data))

        # Create project with metadata
        producer = WritersRoom::Producer.create_project(
          project_path,
          name: project_name,
          concept: options[:concept],
          medium: medium_id
        )

        say "Created project directory: #{project_path}", :green
        say "Created configuration: config.yml", :green
        say "Created project metadata: project.md", :green
        say "Created directories: #{medium.scaffolded_dirs.join(', ')}", :green
        say ""
        say "Configuration:", :cyan
        say "  Provider:   #{options[:provider]}", :white
        say "  Model:      #{options[:model]}", :white
        say "  Medium:     #{medium.label}", :white

        if options[:concept] && !options[:concept].empty?
          say ""
          say "Concept:", :cyan
          say "  #{producer.metadata.concept}", :white
        end

        say ""
        say "Your WritersRoom project is ready!", :green
        say ""
        say "Next steps:", :cyan
        say "  1. cd #{project_name}", :white
        say "  2. Run 'wr' to start an interactive writing session", :white
        next_steps_for_medium(medium).each_with_index do |step, i|
          say "  #{i + 3}. #{step}", :white
        end
      rescue StandardError => e
        say "Error initializing project: #{e.message}", :red
        say e.backtrace.join("\n"), :red if ENV["DEBUG"]
        exit 1
      end

      private

      def choose_medium
        media = WritersRoom::MediumRegistry.all

        say ""
        say "What type of project are you creating?", :cyan
        say ""

        media.each_with_index do |m, i|
          dirs = m.scaffolded_dirs.join(", ")
          say "  #{i + 1}. #{m.label.ljust(20)} (#{dirs})", :white
        end

        say ""
        choice = ask("Choose a medium [1-#{media.size}]:")

        index = choice.to_i - 1
        if index < 0 || index >= media.size
          say "Invalid choice.", :red
          exit 1
        end

        media[index]
      end

      def next_steps_for_medium(medium)
        case medium.id
        when :novel, :novella
          [
            "Use 'wr write develop-concept' to expand your concept",
            "Use 'wr character create NAME' to create characters",
            "Use 'wr chapter create NAME' to outline chapters",
            "Use 'wr arc create NAME' to plan story arcs"
          ]
        when :short_story
          [
            "Use 'wr write develop-concept' to expand your concept",
            "Use 'wr character create NAME' to create characters",
            "Use 'wr scene create NAME' to plan scenes"
          ]
        when :screenplay, :stage_play
          [
            "Use 'wr write develop-concept' to expand your concept",
            "Use 'wr character create NAME' to create characters",
            "Use 'wr scene create NAME' to create scenes",
            "Use 'wr location create NAME' to define locations"
          ]
        when :tv_series
          [
            "Use 'wr write develop-concept' to expand your concept",
            "Use 'wr character create NAME' to create characters",
            "Use 'wr arc create NAME' to plan season arcs"
          ]
        else
          [
            "Use 'wr write develop-concept' to expand your concept",
            "Use 'wr write develop-character' to create character profiles",
            "Use 'wr write create-arc' to plan your story structure"
          ]
        end
      end
    end
  end
end
