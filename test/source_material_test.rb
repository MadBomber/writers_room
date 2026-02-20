# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class SourceMaterialTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("source_test")
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_empty_source_material
    sm = WritersRoom::SourceMaterial.new
    assert_equal "No source material loaded.", sm.summary
    assert_equal "", sm.context_for_llm
  end

  def test_load_file
    file = File.join(@temp_dir, "notes.md")
    File.write(file, "# Research Notes\n\nSome research content.")

    sm = WritersRoom::SourceMaterial.new([file])
    assert_equal 1, sm.entries.size
    assert_equal "notes.md", sm.entries.first[:name]
    assert_match(/Research Notes/, sm.entries.first[:content])
  end

  def test_load_directory
    dir = File.join(@temp_dir, "research")
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "note1.md"), "Note one")
    File.write(File.join(dir, "note2.txt"), "Note two")

    sm = WritersRoom::SourceMaterial.new([dir])
    assert_equal 2, sm.entries.size
  end

  def test_load_writers_room_project
    project = File.join(@temp_dir, "source_project")
    WritersRoom::Producer.create_project(project, name: "Source", concept: "A source project")

    chars_dir = File.join(project, "characters")
    File.write(File.join(chars_dir, "alice.md"),
      WritersRoom::FrontMatter.dump({ "name" => "Alice" }, "A protagonist"))

    sm = WritersRoom::SourceMaterial.new([project])
    # Should have project entry + character entry
    assert sm.entries.size >= 2
    assert sm.entries.any? { |e| e[:type] == :project }
    assert sm.entries.any? { |e| e[:type] == :element }
  end

  def test_summary
    file = File.join(@temp_dir, "notes.md")
    File.write(file, "Content")

    sm = WritersRoom::SourceMaterial.new([file])
    assert_match(/Source material/, sm.summary)
    assert_match(/1 items/, sm.summary)
  end

  def test_context_for_llm
    file = File.join(@temp_dir, "notes.md")
    File.write(file, "Important context")

    sm = WritersRoom::SourceMaterial.new([file])
    context = sm.context_for_llm
    assert_match(/Source Material/, context)
    assert_match(/notes\.md/, context)
  end

  def test_add
    sm = WritersRoom::SourceMaterial.new
    file = File.join(@temp_dir, "late.md")
    File.write(file, "Added later")

    sm.add(file)
    assert_equal 1, sm.entries.size
  end
end
