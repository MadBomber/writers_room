# frozen_string_literal: true

require "fileutils"

module WritersRoom
  # Loads source material (other WritersRoom projects or raw files) as LLM context.
  # Source material provides reference content without being part of the project itself.
  class SourceMaterial
    attr_reader :paths, :entries

    def initialize(paths = [])
      @paths   = Array(paths)
      @entries = []
      load_all
    end

    def add(path)
      @paths << path
      load_path(path)
    end

    def summary
      return "No source material loaded." if @entries.empty?

      lines = ["Source material (#{@entries.size} items):"]
      @entries.each do |entry|
        lines << "  - #{entry[:name]} (#{entry[:type]})"
      end
      lines.join("\n")
    end

    def context_for_llm(max_chars: 10_000)
      return "" if @entries.empty?

      parts = ["## Source Material\n"]
      remaining = max_chars

      @entries.each do |entry|
        chunk = "### #{entry[:name]}\n#{entry[:content]}\n\n"
        break if chunk.length > remaining
        parts << chunk
        remaining -= chunk.length
      end

      parts.join
    end

    private

    def load_all
      @paths.each { |p| load_path(p) }
    end

    def load_path(path)
      path = File.expand_path(path)

      if writers_room_project?(path)
        load_project(path)
      elsif File.directory?(path)
        load_directory(path)
      elsif File.file?(path)
        load_file(path)
      end
    end

    def writers_room_project?(path)
      File.exist?(File.join(path, "project.md"))
    end

    def load_project(path)
      metadata = ProjectMetadata.new(path)
      @entries << {
        name: "Project: #{metadata.name}",
        type: :project,
        path: path,
        content: "Concept: #{metadata.concept}"
      }

      # Load key elements from the project
      %w[characters arcs settings].each do |dir|
        dir_path = File.join(path, dir)
        next unless Dir.exist?(dir_path)

        Dir.glob(File.join(dir_path, "*.md")).first(10).each do |file|
          el = Element.load(file)
          @entries << {
            name: "#{dir.capitalize}: #{el.name}",
            type: :element,
            path: file,
            content: el.body.to_s.slice(0, 500)
          }
        end
      end
    end

    def load_directory(path)
      Dir.glob(File.join(path, "**", "*.{md,txt}")).first(20).each do |file|
        load_file(file)
      end
    end

    def load_file(path)
      return unless File.exist?(path)

      content = File.read(path).slice(0, 2000)
      @entries << {
        name: File.basename(path),
        type: :file,
        path: path,
        content: content
      }
    end
  end
end
