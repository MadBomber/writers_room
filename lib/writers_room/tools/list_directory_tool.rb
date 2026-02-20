# frozen_string_literal: true

module WritersRoom
  # LLM tool that lists files and subdirectories within the project.
  class ListDirectoryTool < ProjectTool
    description "List files and subdirectories within a project directory. " \
                "Returns names with [dir] or [file] markers and file sizes. " \
                "Use to explore the project structure or find specific files."

    param :path, type: "string",
          desc: "Directory path relative to the project root (e.g. 'characters' or '.'). Defaults to project root.",
          required: false

    def execute(path: ".")
      full_path = resolve_path(path)

      return "Directory not found: #{path}" unless Dir.exist?(full_path)

      entries = Dir.children(full_path).sort.map { |name|
        entry_path = File.join(full_path, name)
        if File.directory?(entry_path)
          "[dir]  #{name}/"
        else
          "[file] #{name} (#{File.size(entry_path)} bytes)"
        end
      }

      if entries.empty?
        "Directory '#{path}' is empty."
      else
        entries.join("\n")
      end
    rescue RuntimeError => e
      e.message
    rescue StandardError => e
      "Error listing directory: #{e.message}"
    end
  end
end
