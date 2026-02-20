# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class StoryBibleTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("bible_test")
    # Create a minimal project
    WritersRoom::Producer.create_project(@temp_dir, name: "test", concept: "test", medium: "dialog")
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_regenerate_empty_project
    bible = WritersRoom::StoryBible.new(@temp_dir)
    bible.regenerate

    assert_equal 0, bible.element_count
    refute_nil bible.data["generated_at"]
  end

  def test_regenerate_indexes_elements
    # Create some characters
    chars_dir = File.join(@temp_dir, "characters")
    content = WritersRoom::FrontMatter.dump(
      { "name" => "Alice", "aliases" => ["Al"], "status" => "draft" }, "A protagonist."
    )
    File.write(File.join(chars_dir, "alice.md"), content)

    bible = WritersRoom::StoryBible.new(@temp_dir)
    bible.regenerate

    assert_equal 1, bible.element_count
    entry = bible.data["elements"]["alice"]
    assert_equal "Alice", entry["name"]
    assert_equal ["Al"], entry["aliases"]
    assert_equal "characters", entry["type"]
    assert_equal "draft", entry["status"]
  end

  def test_resolve_by_name
    chars_dir = File.join(@temp_dir, "characters")
    content = WritersRoom::FrontMatter.dump(
      { "name" => "Alice", "aliases" => ["Al"] }, ""
    )
    File.write(File.join(chars_dir, "alice.md"), content)

    bible = WritersRoom::StoryBible.new(@temp_dir)
    bible.regenerate

    assert_equal "Alice", bible.resolve("alice")["name"]
    assert_equal "Alice", bible.resolve("Alice")["name"]
    assert_equal "Alice", bible.resolve("Al")["name"]
    assert_nil bible.resolve("Bob")
  end

  def test_pin_and_unpin_version
    chars_dir = File.join(@temp_dir, "characters")
    content = WritersRoom::FrontMatter.dump({ "name" => "Alice" }, "")
    File.write(File.join(chars_dir, "alice.md"), content)

    bible = WritersRoom::StoryBible.new(@temp_dir)
    bible.regenerate

    assert bible.pin_version("alice", "alice_v2.md")
    assert_equal "alice_v2.md", bible.data["elements"]["alice"]["current"]

    assert bible.unpin_version("alice")
    assert_equal "latest", bible.data["elements"]["alice"]["current"]
  end

  def test_pin_nonexistent_returns_false
    bible = WritersRoom::StoryBible.new(@temp_dir)
    bible.regenerate
    refute bible.pin_version("nonexistent", "v1.md")
  end

  def test_elements_by_type
    chars_dir = File.join(@temp_dir, "characters")
    scenes_dir = File.join(@temp_dir, "scenes")

    File.write(File.join(chars_dir, "alice.md"),
      WritersRoom::FrontMatter.dump({ "name" => "Alice" }, ""))
    File.write(File.join(scenes_dir, "opening.md"),
      WritersRoom::FrontMatter.dump({ "name" => "Opening" }, ""))

    bible = WritersRoom::StoryBible.new(@temp_dir)
    bible.regenerate

    by_type = bible.elements_by_type
    assert by_type.key?("characters")
    assert by_type.key?("scenes")
  end

  def test_story_bible_persists
    chars_dir = File.join(@temp_dir, "characters")
    File.write(File.join(chars_dir, "alice.md"),
      WritersRoom::FrontMatter.dump({ "name" => "Alice" }, ""))

    bible = WritersRoom::StoryBible.new(@temp_dir)
    bible.regenerate

    # Reload from disk
    bible2 = WritersRoom::StoryBible.new(@temp_dir)
    assert_equal 1, bible2.element_count
  end
end
