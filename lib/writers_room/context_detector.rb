# frozen_string_literal: true

module WritersRoom
  # Inspects the current working directory to determine project context.
  # Returns a Context struct describing what the user is working on.
  class ContextDetector
    Context = Struct.new(
      :project_path,    # String or nil
      :medium,          # Medium instance or nil
      :element_type,    # Symbol or nil (:characters, :chapters, etc.)
      :element_slug,    # String or nil (if inside a specific element file's dir)
      :project_state,   # ProjectState or nil
      :in_project?,     # Boolean
      keyword_init: true
    )

    def initialize(cwd = Dir.pwd)
      @cwd = File.expand_path(cwd)
    end

    def detect
      project_path = find_project_root
      return no_project_context unless project_path

      metadata     = ProjectMetadata.new(project_path)
      medium       = MediumRegistry.find(metadata.medium.to_sym) rescue MediumRegistry.find(:dialog)
      element_type = detect_element_type(project_path, medium)
      state        = ProjectState.new(project_path, medium: medium)

      Context.new(
        project_path:  project_path,
        medium:        medium,
        element_type:  element_type,
        element_slug:  nil,
        project_state: state,
        in_project?:   true
      )
    end

    private

    def find_project_root
      dir = @cwd

      loop do
        return dir if File.exist?(File.join(dir, "project.md"))
        parent = File.dirname(dir)
        return nil if parent == dir # reached filesystem root
        dir = parent
      end
    end

    def detect_element_type(project_path, medium)
      # Check if CWD is inside one of the medium's scaffolded dirs
      relative = @cwd.sub("#{project_path}/", "")
      return nil if relative == @cwd # not inside project

      top_dir = relative.split("/").first
      return top_dir.to_sym if medium.scaffolded_dirs.include?(top_dir)

      nil
    end

    def no_project_context
      Context.new(
        project_path:  nil,
        medium:        nil,
        element_type:  nil,
        element_slug:  nil,
        project_state: nil,
        in_project?:   false
      )
    end
  end
end
