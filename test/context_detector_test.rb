# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class ContextDetectorTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("context_test")
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_no_project_detected
    empty = File.join(@temp_dir, "empty")
    FileUtils.mkdir_p(empty)

    ctx = WritersRoom::ContextDetector.new(empty).detect
    refute ctx.in_project?
    assert_nil ctx.project_path
    assert_nil ctx.medium
    assert_nil ctx.element_type
    assert_nil ctx.project_state
  end

  def test_detects_project_at_root
    project = File.join(@temp_dir, "my_novel")
    WritersRoom::Producer.create_project(project, name: "my_novel", medium: "novel")

    ctx = WritersRoom::ContextDetector.new(project).detect
    assert ctx.in_project?
    assert_equal project, ctx.project_path
    assert_equal :novel, ctx.medium.id
    assert_nil ctx.element_type
  end

  def test_detects_project_from_subdirectory
    project = File.join(@temp_dir, "my_novel")
    WritersRoom::Producer.create_project(project, name: "my_novel", medium: "novel")

    chars_dir = File.join(project, "characters")
    ctx = WritersRoom::ContextDetector.new(chars_dir).detect

    assert ctx.in_project?
    assert_equal project, ctx.project_path
    assert_equal :characters, ctx.element_type
  end

  def test_detects_element_type_chapters
    project = File.join(@temp_dir, "my_novel")
    WritersRoom::Producer.create_project(project, name: "my_novel", medium: "novel")

    chapters_dir = File.join(project, "chapters")
    ctx = WritersRoom::ContextDetector.new(chapters_dir).detect

    assert_equal :chapters, ctx.element_type
  end

  def test_project_state_included
    project = File.join(@temp_dir, "my_novel")
    WritersRoom::Producer.create_project(project, name: "my_novel", concept: "A story", medium: "novel")

    ctx = WritersRoom::ContextDetector.new(project).detect
    assert_instance_of WritersRoom::ProjectState, ctx.project_state
  end

  def test_default_medium_for_old_project
    project = File.join(@temp_dir, "old_project")
    FileUtils.mkdir_p(project)
    File.write(File.join(project, "config.yml"), "provider: ollama")
    File.write(File.join(project, "project.md"), "---\nname: old\n---\n")
    FileUtils.mkdir_p(File.join(project, "characters"))

    ctx = WritersRoom::ContextDetector.new(project).detect
    assert ctx.in_project?
    assert_equal :dialog, ctx.medium.id
  end
end
