# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class ProjectScaffolderTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("scaffolder_test")
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
  end

  def test_scaffold_dialog_creates_expected_dirs
    project_path = File.join(@temp_dir, "dialog_project")
    scaffolder = WritersRoom::ProjectScaffolder.new(project_path, medium_id: :dialog)
    scaffolder.scaffold!

    %w[characters scenes transcripts arcs].each do |dir|
      assert Dir.exist?(File.join(project_path, dir)),
             "Expected #{dir} directory to exist for dialog medium"
    end
  end

  def test_scaffold_novel_creates_expected_dirs
    project_path = File.join(@temp_dir, "novel_project")
    scaffolder = WritersRoom::ProjectScaffolder.new(project_path, medium_id: :novel)
    scaffolder.scaffold!

    expected = %w[characters relationships arcs settings locations
                  research timeline backstory chapters parts transcripts]
    expected.each do |dir|
      assert Dir.exist?(File.join(project_path, dir)),
             "Expected #{dir} directory to exist for novel medium"
    end
  end

  def test_scaffold_returns_dir_list
    project_path = File.join(@temp_dir, "test_project")
    scaffolder = WritersRoom::ProjectScaffolder.new(project_path, medium_id: :dialog)
    result = scaffolder.scaffold!

    assert_equal %w[characters scenes transcripts arcs], result
  end

  def test_medium_accessor
    project_path = File.join(@temp_dir, "test_project")
    scaffolder = WritersRoom::ProjectScaffolder.new(project_path, medium_id: :novel)

    assert_equal :novel, scaffolder.medium.id
  end

  def test_defaults_to_dialog
    project_path = File.join(@temp_dir, "test_project")
    scaffolder = WritersRoom::ProjectScaffolder.new(project_path)

    assert_equal :dialog, scaffolder.medium.id
  end

  def test_scaffold_is_idempotent
    project_path = File.join(@temp_dir, "test_project")
    scaffolder = WritersRoom::ProjectScaffolder.new(project_path, medium_id: :dialog)

    scaffolder.scaffold!
    # Write a file into one of the dirs
    File.write(File.join(project_path, "characters", "test.md"), "test")

    scaffolder.scaffold!
    # File should still exist
    assert File.exist?(File.join(project_path, "characters", "test.md"))
  end

  def test_raises_on_unknown_medium
    project_path = File.join(@temp_dir, "test_project")

    assert_raises(WritersRoom::Error) do
      WritersRoom::ProjectScaffolder.new(project_path, medium_id: :nonexistent)
    end
  end

  def test_scaffold_screenplay
    project_path = File.join(@temp_dir, "screenplay_project")
    scaffolder = WritersRoom::ProjectScaffolder.new(project_path, medium_id: :screenplay)
    scaffolder.scaffold!

    %w[characters arcs settings locations acts sequences scenes transcripts].each do |dir|
      assert Dir.exist?(File.join(project_path, dir)),
             "Expected #{dir} directory for screenplay"
    end
  end
end
