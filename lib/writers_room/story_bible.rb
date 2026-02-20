# frozen_string_literal: true

require "yaml"
require "fileutils"

module WritersRoom
  # Auto-generated index mapping slugs/aliases to files.
  # The story bible is the project's lookup table for quick name resolution.
  class StoryBible
    attr_reader :project_path, :data

    def initialize(project_path)
      @project_path = File.expand_path(project_path)
      @bible_path   = File.join(@project_path, "story_bible.yml")
      @data         = load_bible
    end

    def regenerate
      @data = { "elements" => {}, "generated_at" => Time.now.to_s }

      medium = detect_medium
      medium.scaffolded_dirs.each do |dir_name|
        dir_path = File.join(@project_path, dir_name)
        next unless Dir.exist?(dir_path)

        collection = ElementCollection.new(dir_path, element_type: dir_name)
        collection.all.each do |element|
          slug = element.slug
          @data["elements"][slug] = {
            "name"     => element.name,
            "aliases"  => element.aliases,
            "type"     => dir_name,
            "path"     => element.path.sub("#{@project_path}/", ""),
            "status"   => element.status,
            "version"  => element.version,
            "current"  => "latest"
          }
        end
      end

      save_bible
      @data
    end

    def resolve(name_or_alias)
      query = name_or_alias.to_s.downcase.strip

      # Exact match first
      @data.fetch("elements", {}).each do |slug, entry|
        return entry if slug == query
        return entry if entry["name"]&.downcase == query
        return entry if Array(entry["aliases"]).any? { |a| a.to_s.downcase == query }
      end

      # Substring match as fallback
      @data.fetch("elements", {}).each do |slug, entry|
        return entry if slug.include?(query)
        return entry if entry["name"]&.downcase&.include?(query)
        return entry if Array(entry["aliases"]).any? { |a| a.to_s.downcase.include?(query) }
      end

      nil
    end

    def pin_version(slug, version_file)
      entry = @data.dig("elements", slug)
      return false unless entry

      entry["current"] = version_file
      save_bible
      true
    end

    def unpin_version(slug)
      entry = @data.dig("elements", slug)
      return false unless entry

      entry["current"] = "latest"
      save_bible
      true
    end

    def element_count
      @data.fetch("elements", {}).size
    end

    def elements_by_type
      @data.fetch("elements", {}).group_by { |_, v| v["type"] }
        .transform_values { |entries| entries.map { |slug, info| { slug: slug }.merge(info) } }
    end

    private

    def load_bible
      return default_data unless File.exist?(@bible_path)
      YAML.safe_load_file(@bible_path) || default_data
    rescue StandardError
      default_data
    end

    def save_bible
      File.write(@bible_path, YAML.dump(@data))
    end

    def default_data
      { "elements" => {}, "generated_at" => nil }
    end

    def detect_medium
      metadata = ProjectMetadata.new(@project_path)
      MediumRegistry.find(metadata.medium.to_sym)
    rescue StandardError
      MediumRegistry.find(:dialog)
    end
  end
end
