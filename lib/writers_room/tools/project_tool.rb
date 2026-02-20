# frozen_string_literal: true

require "fileutils"

module WritersRoom
  # Base class for tools that operate on files within a project directory.
  # Enforces that all file access stays within the project root.
  class ProjectTool < RobotLab::Tool
    attr_reader :project_path

    def initialize(project_path:, robot: nil)
      super(robot: robot)
      @project_path = File.expand_path(project_path)
    end

    private

    # Resolve a relative path against the project root and verify
    # it does not escape the project directory.
    #
    # @param relative_path [String] path relative to project root
    # @return [String] absolute path within the project
    # @raise [RuntimeError] if the resolved path is outside the project
    def resolve_path(relative_path)
      expanded = File.expand_path(relative_path, @project_path)
      unless expanded.start_with?("#{@project_path}/") || expanded == @project_path
        raise "Access denied: path is outside the project directory"
      end
      expanded
    end
  end
end
