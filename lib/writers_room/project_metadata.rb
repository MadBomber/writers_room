# frozen_string_literal: true

require "yaml"
require "fileutils"

module WritersRoom
  # Manages project metadata including concept, arcs, and timeline.
  # Uses .md files with YAML front matter.
  class ProjectMetadata
    attr_reader :path, :data

    DEFAULT_METADATA = {
      "name" => "",
      "concept" => "",
      "medium" => "dialog",
      "created_at" => Time.now.to_s,
      "story_arcs" => [],
      "timeline" => []
    }.freeze

    def initialize(project_path)
      @project_path = project_path
      @path = File.join(project_path, "project.md")
      @data = load_metadata
    end

    # Load metadata from file
    def load_metadata
      return DEFAULT_METADATA.dup unless File.exist?(path)

      load_from_md
    rescue StandardError => e
      warn "Error loading metadata from #{path}: #{e.message}"
      DEFAULT_METADATA.dup
    end

    # Save metadata to file as .md with front matter
    def save(metadata = @data)
      FileUtils.mkdir_p(File.dirname(@path))

      # Extract body content (description, etc.) from metadata
      body = metadata.delete("body") || metadata.delete(:body) || build_body(metadata)
      meta = metadata.reject { |k, _| k.to_s == "body" }

      content = FrontMatter.dump(meta, body)
      File.write(@path, content)

      @data = metadata
      true
    rescue StandardError => e
      warn "Error saving metadata to #{@path}: #{e.message}"
      false
    end

    # Create new project metadata
    def self.create(project_path, name:, concept: "", medium: "dialog")
      metadata = new(project_path)
      metadata.data["name"] = name
      metadata.data["concept"] = concept
      metadata.data["medium"] = medium.to_s
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
      @data["concept"] || @body || ""
    end

    def concept=(value)
      @data["concept"] = value
      save
    end

    def medium
      @data["medium"] || "dialog"
    end

    def medium=(value)
      @data["medium"] = value.to_s
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

    private

    def load_from_md
      parsed = FrontMatter.load_file(path, symbolize_keys: false)
      meta = parsed[:metadata] || {}
      @body = parsed[:body]

      # Merge defaults for any missing keys
      result = DEFAULT_METADATA.dup.merge(meta)
      result["concept"] = result["concept"] || @body if @body && !@body.empty?
      result
    end

    def build_body(metadata)
      concept_text = metadata["concept"] || metadata[:concept]
      return "" unless concept_text && !concept_text.empty?

      "## Description\n\n#{concept_text}"
    end
  end
end
