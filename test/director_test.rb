# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class DirectorTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("director_test")

    # Create a minimal project structure
    @scenes_dir = File.join(@temp_dir, "scenes")
    @chars_dir = File.join(@temp_dir, "characters")
    @transcripts_dir = File.join(@temp_dir, "transcripts")
    FileUtils.mkdir_p([@scenes_dir, @chars_dir, @transcripts_dir])

    # Create a scene file
    scene_content = WritersRoom::FrontMatter.dump(
      {
        "scene_number" => 1,
        "scene_name" => "Test Scene",
        "location" => "Coffee Shop",
        "characters" => ["Alice", "Bob"],
        "objectives" => ["Have a conversation"]
      },
      "## Context\n\nAlice and Bob meet for coffee."
    )
    @scene_file = File.join(@scenes_dir, "test_scene.md")
    File.write(@scene_file, scene_content)

    # Create character files
    alice_content = WritersRoom::FrontMatter.dump(
      {
        "name" => "Alice",
        "traits" => {
          "personality" => "cheerful",
          "speaking_style" => "casual",
          "background" => "A college student"
        },
        "relationships" => { "Bob" => "friend" }
      },
      "## Background\n\nAlice is upbeat and friendly."
    )
    File.write(File.join(@chars_dir, "alice.md"), alice_content)

    bob_content = WritersRoom::FrontMatter.dump(
      {
        "name" => "Bob",
        "traits" => {
          "personality" => "sarcastic",
          "speaking_style" => "dry humor",
          "background" => "A barista"
        },
        "relationships" => { "Alice" => "friend" }
      },
      ""
    )
    File.write(File.join(@chars_dir, "bob.md"), bob_content)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
  end

  def test_load_scene_parses_front_matter
    # Use send to test the private method
    director = allocate_director
    scene = director.send(:load_scene)

    assert_equal 1, scene[:scene_number]
    assert_equal "Test Scene", scene[:scene_name]
    assert_equal "Coffee Shop", scene[:location]
    assert_equal ["Alice", "Bob"], scene[:characters]
    assert_includes scene[:body], "Alice and Bob meet for coffee"
  end

  def test_load_character_parses_front_matter
    director = allocate_director
    info = director.send(:load_character, "Alice")

    assert_equal "Alice", info[:name]
    assert_equal "cheerful", info[:traits][:personality]
    assert_equal "friend", info[:relationships][:Bob]
    assert_includes info[:body], "upbeat and friendly"
  end

  def test_load_character_returns_nil_for_missing
    director = allocate_director
    info = director.send(:load_character, "Nonexistent")

    assert_nil info
  end

  def test_load_scene_raises_for_missing_file
    assert_raises(RuntimeError) do
      WritersRoom::Director.new(
        scene_file: File.join(@scenes_dir, "missing.md"),
        character_dir: @chars_dir,
        max_lines: 5
      )
    end
  end

  def test_detect_character_dir_from_scene_path
    # Create a project-like structure
    project_dir = File.join(@temp_dir, "projects", "my_show")
    scenes = File.join(project_dir, "scenes")
    chars = File.join(project_dir, "characters")
    FileUtils.mkdir_p([scenes, chars])

    scene_content = WritersRoom::FrontMatter.dump(
      { "scene_name" => "Test", "characters" => [] }, ""
    )
    scene_file = File.join(scenes, "test.md")
    File.write(scene_file, scene_content)

    director = WritersRoom::Director.new(scene_file: scene_file, max_lines: 5)
    # The director should auto-detect the character_dir
    assert director.scene_info[:scene_name] == "Test"
  end

  private

  # Allocate a Director without triggering Room creation (which needs LLM config)
  # by using the scene_file and character_dir that we set up
  def allocate_director
    WritersRoom::Director.new(
      scene_file: @scene_file,
      character_dir: @chars_dir,
      max_lines: 5
    )
  end
end
