# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class ProjectStateTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("state_test")
    @project = File.join(@temp_dir, "test_project")
    WritersRoom::Producer.create_project(@project, name: "test", concept: "A test", medium: "novel")
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_element_counts_empty
    state = WritersRoom::ProjectState.new(@project)
    assert_equal({}, state.element_counts)
  end

  def test_element_counts_with_files
    File.write(File.join(@project, "characters", "alice.md"),
      WritersRoom::FrontMatter.dump({ "name" => "Alice" }, ""))
    File.write(File.join(@project, "characters", "bob.md"),
      WritersRoom::FrontMatter.dump({ "name" => "Bob" }, ""))

    state = WritersRoom::ProjectState.new(@project)
    assert_equal 2, state.element_counts["characters"]
  end

  def test_empty_dirs
    state = WritersRoom::ProjectState.new(@project)
    empties = state.empty_dirs
    assert_includes empties, "characters"
    assert_includes empties, "chapters"
  end

  def test_has_concept
    state = WritersRoom::ProjectState.new(@project)
    assert state.has_concept?
  end

  def test_has_no_concept
    project2 = File.join(@temp_dir, "empty_project")
    WritersRoom::Producer.create_project(project2, name: "empty", medium: "dialog")
    state = WritersRoom::ProjectState.new(project2)
    refute state.has_concept?
  end

  def test_workflow_stage_empty
    project2 = File.join(@temp_dir, "bare")
    WritersRoom::Producer.create_project(project2, name: "bare", medium: "dialog")
    state = WritersRoom::ProjectState.new(project2)
    assert_equal :empty, state.workflow_stage
  end

  def test_workflow_stage_concept_only
    state = WritersRoom::ProjectState.new(@project)
    assert_equal :concept_only, state.workflow_stage
  end

  def test_workflow_stage_populating
    3.times do |i|
      File.write(File.join(@project, "characters", "char_#{i}.md"),
        WritersRoom::FrontMatter.dump({ "name" => "Char #{i}" }, ""))
    end
    state = WritersRoom::ProjectState.new(@project)
    assert_equal :populating, state.workflow_stage
  end

  def test_summary_is_string
    state = WritersRoom::ProjectState.new(@project)
    assert_kind_of String, state.summary
    assert_match(/Novel/, state.summary)
  end
end
