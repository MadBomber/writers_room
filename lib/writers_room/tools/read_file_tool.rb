# frozen_string_literal: true

module WritersRoom
  # LLM tool that reads file contents within the project directory.
  class ReadFileTool < ProjectTool
    def name = "read_file"

    description "Read the contents of a file within the project directory. " \
                "Returns the file content as text. Use for reading character files, " \
                "chapters, settings, or any other project file."

    param :path, type: "string",
          desc: "File path relative to the project root (e.g. 'characters/alice.md')",
          required: true

    def execute(path:, **)
      full_path = resolve_path(path)

      return "File not found: #{path}" unless File.exist?(full_path)
      return "Not a file: #{path}" unless File.file?(full_path)

      File.read(full_path)
    rescue RuntimeError => e
      e.message
    rescue StandardError => e
      "Error reading file: #{e.message}"
    end
  end
end
