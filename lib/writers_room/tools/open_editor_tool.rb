# frozen_string_literal: true

module WritersRoom
  # LLM tool that opens the user's editor on a project file.
  # The editor launches in the background as a side effect so the
  # chat session continues in the foreground.
  class OpenEditorTool < ProjectTool
    def name = "open_editor"

    description "Open the user's text editor on a project file. " \
                "The editor launches in the background so the chat continues. " \
                "Use when the user asks to edit, open, or work on a file directly."

    param :path, type: "string",
          desc: "File path relative to the project root (e.g. 'characters/hard_kode.md')",
          required: true

    def execute(path:, **)
      full_path = resolve_path(path)

      return "File not found: #{path}" unless File.exist?(full_path)
      return "Not a file: #{path}" unless File.file?(full_path)

      editor = ENV["VISUAL"] || ENV["EDITOR"] || "vi"

      pid = Process.spawn(editor, full_path, [:out, :err] => "/dev/null")
      Process.detach(pid)

      "Opened #{path} in #{editor} (background). The user can edit while we continue chatting."
    rescue RuntimeError => e
      e.message
    rescue StandardError => e
      "Error opening editor: #{e.message}"
    end
  end
end
