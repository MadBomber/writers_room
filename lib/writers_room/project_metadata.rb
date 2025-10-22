# frozen_string_literal: true

require "yaml"
require "fileutils"

module WritersRoom
  # Manages project metadata including concept, arcs, and timeline
  class ProjectMetadata
    attr_reader :path, :data

    DEFAULT_METADATA = {
      "name" => "",
      "concept" => "",
      "created_at" => Time.now.to_s,
      "story_arcs" => [],
      "timeline" => []
    }.freeze

    def initialize(project_path)
      @path = File.join(project_path, "project.yml")
      @data = load_metadata
    end

    # Load metadata from file
    def load_metadata
      return DEFAULT_METADATA.dup unless File.exist?(path)

      YAML.load_file(path) || DEFAULT_METADATA.dup
    rescue StandardError => e
      warn "Error loading metadata from #{path}: #{e.message}"
      DEFAULT_METADATA.dup
    end

    # Save metadata to file
    def save(metadata = @data)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, YAML.dump(metadata))
      @data = metadata
      true
    rescue StandardError => e
      warn "Error saving metadata to #{path}: #{e.message}"
      false
    end

    # Create new project metadata
    def self.create(project_path, name:, concept: "")
      metadata = new(project_path)
      metadata.data["name"] = name
      metadata.data["concept"] = concept
      metadata.data["created_at"] = Time.now.to_s
      metadata.save
      metadata
    end

    # Get/set methods
    def name
      @data["name"]
    end

    def name=(value)
      @data["name"] = value
      save
    end

    def concept
      @data["concept"]
    end

    def concept=(value)
      @data["concept"] = value
      save
    end

    def story_arcs
      @data["story_arcs"] || []
    end

    def add_story_arc(arc)
      @data["story_arcs"] ||= []
      @data["story_arcs"] << arc
      save
    end

    def timeline
      @data["timeline"] || []
    end

    def add_timeline_entry(entry)
      @data["timeline"] ||= []
      @data["timeline"] << entry
      save
    end
  end
end
