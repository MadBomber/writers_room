# frozen_string_literal: true

require "fileutils"

module WritersRoom
  # Manages file versioning for story elements.
  # Creates slug_v1.md, slug_v2.md, etc. in the same directory.
  class Versioner
    attr_reader :dir, :slug

    def initialize(dir, slug)
      @dir  = dir
      @slug = slug
    end

    def versions
      pattern = File.join(@dir, "#{@slug}_v*.md")
      Dir.glob(pattern).sort_by { |f| extract_version_number(f) }
    end

    def version_count
      versions.length
    end

    def latest_version
      versions.last
    end

    def current_version
      latest_version
    end

    def create_new_version(body: "", metadata: {}, based_on: nil)
      next_num = version_count + 1
      version_file = "#{@slug}_v#{next_num}.md"
      version_path = File.join(@dir, version_file)

      meta = FrontMatter.stringify_keys(metadata).merge(
        "version" => next_num,
        "status"  => metadata["status"] || metadata[:status] || "draft",
        "based_on" => based_on
      )

      # If based_on is specified, copy body from previous version if no body given
      if based_on && body.empty?
        source = File.join(@dir, based_on)
        if File.exist?(source)
          parsed = FrontMatter.load_file(source, symbolize_keys: false)
          body = parsed[:body]
        end
      end

      content = FrontMatter.dump(meta, body)
      File.write(version_path, content)

      Element.load(version_path)
    end

    def version_at(number)
      path = File.join(@dir, "#{@slug}_v#{number}.md")
      return nil unless File.exist?(path)
      Element.load(path)
    end

    private

    def extract_version_number(path)
      basename = File.basename(path, ".md")
      match = basename.match(/_v(\d+)$/)
      match ? match[1].to_i : 0
    end
  end
end
