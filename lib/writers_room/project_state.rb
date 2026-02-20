# frozen_string_literal: true

module WritersRoom
  # Summarizes the current state of a project: what exists, what's missing,
  # what's in progress, and what stage the project is in.
  class ProjectState
    attr_reader :project_path, :medium, :metadata

    def initialize(project_path, medium: nil)
      @project_path = File.expand_path(project_path)
      @metadata     = ProjectMetadata.new(@project_path)
      @medium       = medium || MediumRegistry.find(@metadata.medium.to_sym)
    end

    def element_counts
      counts = {}
      @medium.scaffolded_dirs.each do |dir|
        dir_path = File.join(@project_path, dir)
        next unless Dir.exist?(dir_path)
        files = Dir.glob(File.join(dir_path, "*.md")).reject { |f| f.match?(/_v\d+\.md\z/) }
        counts[dir] = files.count if files.count > 0
      end
      counts
    end

    def missing_dirs
      @medium.scaffolded_dirs.reject do |dir|
        Dir.exist?(File.join(@project_path, dir))
      end
    end

    def empty_dirs
      @medium.scaffolded_dirs.select do |dir|
        dir_path = File.join(@project_path, dir)
        Dir.exist?(dir_path) && Dir.glob(File.join(dir_path, "*.md")).empty?
      end
    end

    def has_concept?
      !@metadata.concept.to_s.strip.empty?
    end

    def has_characters?
      dir = File.join(@project_path, "characters")
      Dir.exist?(dir) && !Dir.glob(File.join(dir, "*.md")).empty?
    end

    def workflow_stage
      counts = element_counts
      return :empty if counts.empty? && !has_concept?
      return :concept_only if counts.empty? && has_concept?
      return :populating if counts.values.sum < 5
      :developing
    end

    def summary
      counts = element_counts
      lines = []
      lines << "Project: #{@metadata.name}" unless @metadata.name.to_s.empty?
      lines << "Medium: #{@medium.label}"
      lines << "Stage: #{workflow_stage}"

      if counts.any?
        lines << "Elements:"
        counts.each { |dir, count| lines << "  #{dir}: #{count}" }
      end

      empty = empty_dirs
      if empty.any?
        lines << "Empty: #{empty.join(', ')}"
      end

      lines.join("\n")
    end
  end
end
