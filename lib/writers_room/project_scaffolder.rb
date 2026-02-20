# frozen_string_literal: true

require "fileutils"

module WritersRoom
  # Creates project directory structure based on medium type.
  class ProjectScaffolder
    attr_reader :project_path, :medium

    def initialize(project_path, medium_id: :dialog)
      @project_path = File.expand_path(project_path)
      @medium       = MediumRegistry.find(medium_id)
    end

    def scaffold!
      FileUtils.mkdir_p(@project_path)
      create_directories
      create_story_bible
      @medium.scaffolded_dirs
    end

    def create_directories
      @medium.scaffolded_dirs.each do |dir|
        dir_path = File.join(@project_path, dir)
        FileUtils.mkdir_p(dir_path) unless Dir.exist?(dir_path)
      end
    end

    def create_story_bible
      bible_path = File.join(@project_path, "story_bible.yml")
      return if File.exist?(bible_path)

      File.write(bible_path, YAML.dump(
        "elements" => {},
        "generated_at" => nil
      ))
    end
  end
end
