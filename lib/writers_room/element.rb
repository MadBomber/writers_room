# frozen_string_literal: true

require "fileutils"

module WritersRoom
  # Lightweight value object wrapping a FrontMatter file.
  # Represents any story element: character, location, chapter, theme, etc.
  class Element
    attr_reader :path, :slug, :metadata, :body

    def initialize(path:, metadata: {}, body: "")
      @path     = path
      @slug     = File.basename(path, ".md")
      @metadata = metadata
      @body     = body
    end

    def name
      metadata[:name] || metadata["name"] || slug.tr("_", " ").split.map(&:capitalize).join(" ")
    end

    def aliases
      Array(metadata[:aliases] || metadata["aliases"])
    end

    def element_type
      metadata[:element_type] || metadata["element_type"]
    end

    def version
      metadata[:version] || metadata["version"]
    end

    def status
      metadata[:status] || metadata["status"]
    end

    def based_on
      metadata[:based_on] || metadata["based_on"]
    end

    def matches_name?(query)
      normalized = query.to_s.downcase.strip
      return true if slug == sanitize(normalized)
      return true if name.downcase == normalized
      aliases.any? { |a| a.to_s.downcase == normalized }
    end

    def self.load(path, symbolize_keys: true)
      parsed = FrontMatter.load_file(path, symbolize_keys: symbolize_keys)
      new(path: path, metadata: parsed[:metadata], body: parsed[:body])
    end

    def self.create(dir, name, metadata: {}, body: "")
      slug = sanitize(name)
      path = File.join(dir, "#{slug}.md")

      raise Error, "'#{name}' already exists at #{path}" if File.exist?(path)

      FileUtils.mkdir_p(dir)
      meta = { "name" => name }.merge(FrontMatter.stringify_keys(metadata))
      content = FrontMatter.dump(meta, body)
      File.write(path, content)

      load(path)
    end

    def save
      meta = FrontMatter.stringify_keys(@metadata)
      content = FrontMatter.dump(meta, @body)
      File.write(@path, content)
      self
    end

    def reload
      parsed = FrontMatter.load_file(@path, symbolize_keys: true)
      @metadata = parsed[:metadata]
      @body     = parsed[:body]
      self
    end

    def to_h
      { slug: slug, name: name, aliases: aliases, path: path,
        version: version, status: status }
    end

    def self.sanitize(name)
      name.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/(^_|_$)/, "")
    end

    private

    def sanitize(name)
      self.class.sanitize(name)
    end
  end
end
