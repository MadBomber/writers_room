# frozen_string_literal: true

require "yaml"
require "fileutils"

module WritersRoom
  # Producer manages the overall production: creates characters, scenes,
  # and coordinates directors to run the full production.
  class Producer
    attr_reader :project_path, :metadata

    def initialize(project_path = Dir.pwd)
      @project_path = File.expand_path(project_path)

      unless File.exist?(File.join(@project_path, "config.yml")) ||
             File.exist?(File.join(@project_path, "project.md"))
        raise Error, "No project found. Run 'wr init <project_name>' first."
      end

      @metadata = ProjectMetadata.new(@project_path)
      ensure_project_structure
    end

    # Create a new project with concept
    def self.create_project(project_path, name:, concept: "", **config_options)
      FileUtils.mkdir_p(project_path)

      # Write config.yml if it doesn't already exist
      config_path = File.join(project_path, "config.yml")
      unless File.exist?(config_path)
        config_data = {
          "provider" => config_options[:provider] || "ollama",
          "model_name" => config_options[:model_name] || "gpt-oss:20b"
        }
        File.write(config_path, YAML.dump(config_data))
      end

      # Create metadata with concept (saves as .md)
      ProjectMetadata.create(project_path, name: name, concept: concept)

      # Create required directories
      producer = new(project_path)
      producer.send(:ensure_project_structure)
      producer
    end

    # Validate that the project has the required structure
    def validate_project
      required_dirs = %w[characters scenes transcripts arcs]
      missing = required_dirs.reject { |dir| Dir.exist?(File.join(@project_path, dir)) }

      if missing.any?
        raise Error, "Missing required directories: #{missing.join(', ')}"
      end

      true
    end

    # Create a new character from a template (.md with front matter)
    def create_character(name, traits = {})
      characters_dir = File.join(@project_path, "characters")
      character_file = File.join(characters_dir, "#{sanitize_filename(name)}.md")

      if File.exist?(character_file)
        raise Error, "Character '#{name}' already exists"
      end

      metadata = {
        "name" => name,
        "traits" => {
          "personality" => traits[:personality] || "neutral",
          "speaking_style" => traits[:speaking_style] || "conversational",
          "background" => traits[:background] || ""
        },
        "goals" => traits[:goals] || [],
        "relationships" => traits[:relationships] || {}
      }

      body = ""
      content = FrontMatter.dump(metadata, body)
      File.write(character_file, content)
      character_file
    end

    # Create a new scene (.md with front matter)
    def create_scene(name, description, characters = [])
      scenes_dir = File.join(@project_path, "scenes")
      scene_file = File.join(scenes_dir, "#{sanitize_filename(name)}.md")

      if File.exist?(scene_file)
        raise Error, "Scene '#{name}' already exists"
      end

      metadata = {
        "scene_name" => name,
        "description" => description,
        "setting" => "",
        "characters" => characters,
        "objectives" => []
      }

      body = ""
      content = FrontMatter.dump(metadata, body)
      File.write(scene_file, content)
      scene_file
    end

    # List all characters in the project
    def list_characters
      characters_dir = File.join(@project_path, "characters")
      return [] unless Dir.exist?(characters_dir)

      Dir.glob(File.join(characters_dir, "*.md")).map do |file|
        data = load_character_file(file)
        {
          name: data["name"] || data[:name],
          file: file,
          personality: data.dig("traits", "personality") || data.dig(:traits, :personality)
        }
      end
    end

    # List all scenes in the project
    def list_scenes
      scenes_dir = File.join(@project_path, "scenes")
      return [] unless Dir.exist?(scenes_dir)

      Dir.glob(File.join(scenes_dir, "*.md")).map do |file|
        data = load_scene_file(file)
        {
          name: data["scene_name"] || data[:scene_name],
          file: file,
          characters: data["characters"] || data[:characters] || []
        }
      end
    end

    # Chat about production planning
    def chat_about_production(scene_files)
      require_relative "chat_session"

      scenes_list = scene_files.map { |f| File.basename(f) }.join(", ")

      context = {
        project_name: @metadata.name,
        project_concept: @metadata.concept,
        task: "Planning production",
        subject: "Production Planning",
        additional: "Available scenes: #{scenes_list}\nTotal scenes: #{scene_files.count}"
      }

      session = ChatSession.new(context: context)
      session.start

      chat_log_path = File.join(@project_path, "production_chat_#{Time.now.to_i}.md")
      session.save(chat_log_path)

      {
        chat_log: chat_log_path,
        summary: session.summary,
        messages: session.messages
      }
    end

    # Run a full production (all scenes or specific scenes)
    def produce(scene_files = nil, options = {})
      scene_files ||= find_scene_files
      scene_files = [scene_files] if scene_files.is_a?(String)

      results = []

      scene_files.each do |scene_file|
        unless File.exist?(scene_file)
          puts "Warning: Scene file not found: #{scene_file}"
          next
        end

        puts "=" * 60
        puts "PRODUCING SCENE: #{File.basename(scene_file)}"
        puts "=" * 60

        director = Director.new(
          scene_file: scene_file,
          character_dir: File.join(@project_path, "characters"),
          max_lines: options[:max_lines]
        )

        begin
          director.action!
          transcript_file = director.save_transcript(options[:output])

          results << {
            scene: scene_file,
            transcript: transcript_file,
            statistics: director.statistics,
            status: :completed
          }
        rescue => e
          puts "Error producing scene: #{e.message}"
          results << {
            scene: scene_file,
            error: e.message,
            status: :failed
          }
        ensure
          director.cut! rescue nil
        end
      end

      results
    end

    # Generate a production report across all transcripts
    def generate_report
      transcripts_dir = File.join(@project_path, "transcripts")
      return {} unless Dir.exist?(transcripts_dir)

      transcripts = Dir.glob(File.join(transcripts_dir, "*.txt"))

      total_lines = 0
      total_characters = {}

      transcripts.each do |transcript|
        content = File.read(transcript)
        lines = content.lines

        lines.each do |line|
          next if line.strip.empty?
          next unless line.match?(/^(\w+):/)

          character = line.match(/^(\w+):/)[1]
          total_characters[character] ||= 0
          total_characters[character] += 1
          total_lines += 1
        end
      end

      {
        total_scenes: transcripts.count,
        total_lines: total_lines,
        lines_by_character: total_characters,
        transcripts: transcripts.map { |t| File.basename(t) }
      }
    end

    private

    def ensure_project_structure
      required_dirs = %w[characters scenes transcripts arcs]
      required_dirs.each do |dir|
        dir_path = File.join(@project_path, dir)
        FileUtils.mkdir_p(dir_path) unless Dir.exist?(dir_path)
      end
    end

    def sanitize_filename(name)
      name.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/(^_|_$)/, "")
    end

    def find_scene_files
      Dir.glob(File.join(@project_path, "scenes", "*.md"))
    end

    def load_character_file(file)
      parsed = FrontMatter.load_file(file, symbolize_keys: false)
      parsed[:metadata]
    end

    def load_scene_file(file)
      parsed = FrontMatter.load_file(file, symbolize_keys: false)
      parsed[:metadata]
    end
  end
end
