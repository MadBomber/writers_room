# frozen_string_literal: true

module WritersRoom
  # Scans element bodies for name/alias references and builds a reference graph.
  class CrossReference
    attr_reader :project_path, :references

    def initialize(project_path)
      @project_path = File.expand_path(project_path)
      @references   = {}  # slug => [referenced_slugs]
    end

    def scan
      @references = {}
      all_elements = load_all_elements
      name_map = build_name_map(all_elements)

      all_elements.each do |element|
        refs = find_references(element.body, name_map, exclude: element.slug)
        @references[element.slug] = refs unless refs.empty?
      end

      @references
    end

    def references_for(slug)
      @references[slug] || []
    end

    def referenced_by(slug)
      @references.select { |_, refs| refs.include?(slug) }.keys
    end

    def graph
      nodes = Set.new
      edges = []

      @references.each do |from, to_list|
        nodes << from
        to_list.each do |to|
          nodes << to
          edges << { from: from, to: to }
        end
      end

      { nodes: nodes.to_a, edges: edges }
    end

    private

    def load_all_elements
      elements = []
      metadata = ProjectMetadata.new(@project_path)
      medium = MediumRegistry.find(metadata.medium.to_sym) rescue MediumRegistry.find(:dialog)

      medium.scaffolded_dirs.each do |dir|
        dir_path = File.join(@project_path, dir)
        next unless Dir.exist?(dir_path)

        collection = ElementCollection.new(dir_path, element_type: dir)
        elements.concat(collection.all)
      end

      elements
    end

    def build_name_map(elements)
      map = {}  # name/alias => slug

      elements.each do |el|
        map[el.name.downcase] = el.slug
        el.aliases.each { |a| map[a.to_s.downcase] = el.slug }
      end

      map
    end

    def find_references(body, name_map, exclude:)
      return [] if body.nil? || body.empty?

      found = Set.new
      text = body.downcase

      name_map.each do |name, slug|
        next if slug == exclude
        next if name.length < 3  # skip very short aliases

        # Word boundary match
        if text.match?(/\b#{Regexp.escape(name)}\b/)
          found << slug
        end
      end

      found.to_a
    end
  end
end
