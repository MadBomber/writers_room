# frozen_string_literal: true

module WritersRoom
  # LLM tool that writes or updates files within the project directory.
  class WriteFileTool < ProjectTool
    description "Write or update a file within the project directory. " \
                "Creates the file if it does not exist, or overwrites it. " \
                "Creates any missing parent directories automatically. " \
                "For element files (characters, chapters, etc.), use YAML front matter format:\n" \
                "---\nname: Character Name\nstatus: draft\n---\n\nBody content here."

    param :path, type: "string",
          desc: "File path relative to the project root (e.g. 'characters/alice.md')",
          required: true
    param :content, type: "string",
          desc: "The full content to write to the file",
          required: true

    def execute(path:, content:)
      full_path = resolve_path(path)

      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)

      "Wrote #{content.length} bytes to #{path}"
    rescue RuntimeError => e
      e.message
    rescue StandardError => e
      "Error writing file: #{e.message}"
    end
  end
end
