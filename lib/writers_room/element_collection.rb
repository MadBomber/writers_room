# frozen_string_literal: true

module WritersRoom
  # Manages all elements of a given type within a directory.
  class ElementCollection
    attr_reader :dir, :element_type

    def initialize(dir, element_type: nil)
      @dir          = dir
      @element_type = element_type
    end

    def all
      return [] unless Dir.exist?(@dir)

      Dir.glob(File.join(@dir, "*.md")).sort.reject { |p|
        File.basename(p) =~ /_v\d+\.md\z/
      }.map do |path|
        Element.load(path)
      end
    end

    def find_by_slug(slug)
      path = File.join(@dir, "#{slug}.md")
      return nil unless File.exist?(path)
      Element.load(path)
    end

    def find_by_name_or_alias(query)
      all.find { |el| el.matches_name?(query) }
    end

    def search(query)
      all.select { |el| el.matches_name?(query) }
    end

    def create(name, metadata: {}, body: "")
      meta = metadata.merge("element_type" => @element_type&.to_s)
      Element.create(@dir, name, metadata: meta, body: body)
    end

    def list
      all.map(&:to_h)
    end

    def count
      return 0 unless Dir.exist?(@dir)
      Dir.glob(File.join(@dir, "*.md")).reject { |p|
        File.basename(p) =~ /_v\d+\.md\z/
      }.count
    end

    def empty?
      count.zero?
    end

    def slugs
      all.map(&:slug)
    end
  end
end
