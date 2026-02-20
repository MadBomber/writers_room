# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class ProjectToolTest < Minitest::Test
  def setup
    @project_dir = Dir.mktmpdir("wr_test_project")
  end

  def teardown
    FileUtils.rm_rf(@project_dir)
  end

  def test_resolve_path_within_project
    tool = WritersRoom::ReadFileTool.new(project_path: @project_dir)
    # Tool should not raise for valid relative paths
    File.write(File.join(@project_dir, "test.md"), "hello")
    result = tool.execute(path: "test.md")
    assert_equal "hello", result
  end

  def test_resolve_path_blocks_parent_traversal
    tool = WritersRoom::ReadFileTool.new(project_path: @project_dir)
    result = tool.execute(path: "../../etc/passwd")
    assert_equal "Access denied: path is outside the project directory", result
  end

  def test_resolve_path_blocks_absolute_path
    tool = WritersRoom::ReadFileTool.new(project_path: @project_dir)
    result = tool.execute(path: "/etc/passwd")
    assert_equal "Access denied: path is outside the project directory", result
  end
end

class ReadFileToolTest < Minitest::Test
  def setup
    @project_dir = Dir.mktmpdir("wr_test_project")
    @tool = WritersRoom::ReadFileTool.new(project_path: @project_dir)
  end

  def teardown
    FileUtils.rm_rf(@project_dir)
  end

  def test_reads_existing_file
    File.write(File.join(@project_dir, "story.md"), "Once upon a time...")
    result = @tool.execute(path: "story.md")
    assert_equal "Once upon a time...", result
  end

  def test_reads_file_in_subdirectory
    FileUtils.mkdir_p(File.join(@project_dir, "characters"))
    File.write(File.join(@project_dir, "characters", "alice.md"), "---\nname: Alice\n---\nA curious girl.")
    result = @tool.execute(path: "characters/alice.md")
    assert_includes result, "name: Alice"
    assert_includes result, "A curious girl."
  end

  def test_nonexistent_file
    result = @tool.execute(path: "nope.md")
    assert_equal "File not found: nope.md", result
  end

  def test_directory_is_not_a_file
    FileUtils.mkdir_p(File.join(@project_dir, "chapters"))
    result = @tool.execute(path: "chapters")
    assert_equal "Not a file: chapters", result
  end
end

class WriteFileToolTest < Minitest::Test
  def setup
    @project_dir = Dir.mktmpdir("wr_test_project")
    @tool = WritersRoom::WriteFileTool.new(project_path: @project_dir)
  end

  def teardown
    FileUtils.rm_rf(@project_dir)
  end

  def test_creates_new_file
    result = @tool.execute(path: "notes.md", content: "Some notes")
    assert_includes result, "Wrote"
    assert_includes result, "notes.md"
    assert_equal "Some notes", File.read(File.join(@project_dir, "notes.md"))
  end

  def test_creates_intermediate_directories
    result = @tool.execute(path: "chapters/ch1.md", content: "Chapter 1")
    assert_includes result, "Wrote"
    assert File.exist?(File.join(@project_dir, "chapters", "ch1.md"))
  end

  def test_overwrites_existing_file
    path = File.join(@project_dir, "draft.md")
    File.write(path, "old content")
    @tool.execute(path: "draft.md", content: "new content")
    assert_equal "new content", File.read(path)
  end

  def test_blocks_escape_attempt
    result = @tool.execute(path: "../../evil.txt", content: "bad")
    assert_equal "Access denied: path is outside the project directory", result
  end

  def test_reports_byte_count
    content = "Hello, world!"
    result = @tool.execute(path: "test.md", content: content)
    assert_equal "Wrote #{content.length} bytes to test.md", result
  end
end

class ListDirectoryToolTest < Minitest::Test
  def setup
    @project_dir = Dir.mktmpdir("wr_test_project")
    @tool = WritersRoom::ListDirectoryTool.new(project_path: @project_dir)
  end

  def teardown
    FileUtils.rm_rf(@project_dir)
  end

  def test_lists_project_root
    FileUtils.mkdir_p(File.join(@project_dir, "characters"))
    File.write(File.join(@project_dir, "project.md"), "---\nname: Test\n---")

    result = @tool.execute(path: ".")
    assert_includes result, "[dir]  characters/"
    assert_includes result, "[file] project.md"
  end

  def test_lists_subdirectory
    FileUtils.mkdir_p(File.join(@project_dir, "characters"))
    File.write(File.join(@project_dir, "characters", "alice.md"), "content")
    File.write(File.join(@project_dir, "characters", "bob.md"), "content")

    result = @tool.execute(path: "characters")
    assert_includes result, "[file] alice.md"
    assert_includes result, "[file] bob.md"
  end

  def test_defaults_to_project_root
    File.write(File.join(@project_dir, "readme.md"), "hi")
    result = @tool.execute
    assert_includes result, "[file] readme.md"
  end

  def test_nonexistent_directory
    result = @tool.execute(path: "nonexistent")
    assert_equal "Directory not found: nonexistent", result
  end

  def test_empty_directory
    FileUtils.mkdir_p(File.join(@project_dir, "empty"))
    result = @tool.execute(path: "empty")
    assert_equal "Directory 'empty' is empty.", result
  end

  def test_blocks_escape_attempt
    result = @tool.execute(path: "../../")
    assert_equal "Access denied: path is outside the project directory", result
  end

  def test_shows_file_sizes
    File.write(File.join(@project_dir, "small.md"), "hi")
    result = @tool.execute(path: ".")
    assert_match(/small\.md \(\d+ bytes\)/, result)
  end
end
