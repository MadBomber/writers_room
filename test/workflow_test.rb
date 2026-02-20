# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class WorkflowTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("workflow_test")
    @project = File.join(@temp_dir, "test_project")
    WritersRoom::Producer.create_project(@project, name: "test", concept: "A test", medium: "novel")
    @medium = WritersRoom::MediumRegistry.find(:novel)
    @workflow = WritersRoom::Workflow.new(@medium)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_statuses
    assert_equal %w[outline draft revision final], @workflow.statuses
  end

  def test_workflows
    assert_equal [:outlining, :drafting, :revision, :final], @workflow.workflows
  end

  def test_valid_forward_transition
    assert @workflow.valid_status_transition?("outline", "draft")
    assert @workflow.valid_status_transition?("draft", "revision")
    assert @workflow.valid_status_transition?("outline", "final")
  end

  def test_valid_back_one_step
    assert @workflow.valid_status_transition?("revision", "draft")
  end

  def test_invalid_back_two_steps
    refute @workflow.valid_status_transition?("final", "draft")
  end

  def test_invalid_unknown_status
    refute @workflow.valid_status_transition?("unknown", "draft")
  end

  def test_next_status
    assert_equal "draft", @workflow.next_status("outline")
    assert_equal "revision", @workflow.next_status("draft")
    assert_nil @workflow.next_status("final")
  end

  def test_current_stage
    assert_equal :concept_only, @workflow.current_stage(@project)
  end

  def test_next_steps
    steps = @workflow.next_steps(@project)
    assert_kind_of Array, steps
    assert steps.any?
  end
end
