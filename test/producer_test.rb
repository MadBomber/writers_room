# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

class ProducerTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("producer_test")
    @project_path = File.join(@temp_dir, "test_project")

    # Create a basic project structure
    WritersRoom::Config.create_project(@project_path)
    @producer = WritersRoom::Producer.new(@project_path)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
  end

  def test_initializes_with_valid_project
    assert_instance_of WritersRoom::Producer, @producer
    assert_equal @project_path, @producer.project_path
    assert_instance_of WritersRoom::Config, @producer.config
  end

  def test_raises_error_without_config
    empty_dir = File.join(@temp_dir, "no_config")
    FileUtils.mkdir_p(empty_dir)

    error = assert_raises(WritersRoom::Error) do
      WritersRoom::Producer.new(empty_dir)
    end

    assert_match(/No config.yml found/, error.message)
  end

  def test_ensures_project_structure
    required_dirs = %w[characters scenes transcripts logs]

    required_dirs.each do |dir|
      assert Dir.exist?(File.join(@project_path, dir)),
             "Expected #{dir} directory to exist"
    end
  end

  def test_validate_project_success
    assert @producer.validate_project
  end

  def test_validate_project_fails_with_missing_directories
    # Remove a required directory
    FileUtils.rm_rf(File.join(@project_path, "characters"))

    error = assert_raises(WritersRoom::Error) do
      @producer.validate_project
    end

    assert_match(/Missing required directories/, error.message)
    assert_match(/characters/, error.message)
  end

  def test_create_character
    character_file = @producer.create_character(
      "Alice",
      personality: "cheerful",
      speaking_style: "casual",
      background: "A young writer"
    )

    assert File.exist?(character_file)
    assert_match(/alice\.yml$/, character_file)

    data = YAML.load_file(character_file)
    assert_equal "Alice", data["name"]
    assert_equal "cheerful", data["traits"]["personality"]
    assert_equal "casual", data["traits"]["speaking_style"]
    assert_equal "A young writer", data["traits"]["background"]
  end

  def test_create_character_with_defaults
    character_file = @producer.create_character("Bob")

    assert File.exist?(character_file)

    data = YAML.load_file(character_file)
    assert_equal "Bob", data["name"]
    assert_equal "neutral", data["traits"]["personality"]
    assert_equal "conversational", data["traits"]["speaking_style"]
  end

  def test_create_character_raises_error_if_exists
    @producer.create_character("Alice")

    error = assert_raises(WritersRoom::Error) do
      @producer.create_character("Alice")
    end

    assert_match(/already exists/, error.message)
  end

  def test_create_scene
    scene_file = @producer.create_scene(
      "Coffee Shop",
      "A busy coffee shop conversation",
      ["Alice", "Bob"]
    )

    assert File.exist?(scene_file)
    assert_match(/coffee_shop\.yml$/, scene_file)

    data = YAML.load_file(scene_file)
    assert_equal "Coffee Shop", data["scene_name"]
    assert_equal "A busy coffee shop conversation", data["description"]
    assert_equal ["Alice", "Bob"], data["characters"]
  end

  def test_create_scene_raises_error_if_exists
    @producer.create_scene("Coffee Shop", "Description", [])

    error = assert_raises(WritersRoom::Error) do
      @producer.create_scene("Coffee Shop", "Another description", [])
    end

    assert_match(/already exists/, error.message)
  end

  def test_list_characters_empty
    characters = @producer.list_characters
    assert_empty characters
  end

  def test_list_characters
    @producer.create_character("Alice", personality: "cheerful")
    @producer.create_character("Bob", personality: "grumpy")

    characters = @producer.list_characters
    assert_equal 2, characters.count

    alice = characters.find { |c| c[:name] == "Alice" }
    assert_equal "cheerful", alice[:personality]

    bob = characters.find { |c| c[:name] == "Bob" }
    assert_equal "grumpy", bob[:personality]
  end

  def test_list_scenes_empty
    scenes = @producer.list_scenes
    assert_empty scenes
  end

  def test_list_scenes
    @producer.create_scene("Scene One", "First scene", ["Alice"])
    @producer.create_scene("Scene Two", "Second scene", ["Bob"])

    scenes = @producer.list_scenes
    assert_equal 2, scenes.count

    scene_one = scenes.find { |s| s[:name] == "Scene One" }
    assert_equal ["Alice"], scene_one[:characters]

    scene_two = scenes.find { |s| s[:name] == "Scene Two" }
    assert_equal ["Bob"], scene_two[:characters]
  end

  def test_generate_report_empty
    report = @producer.generate_report

    assert_equal 0, report[:total_scenes]
    assert_equal 0, report[:total_lines]
    assert_empty report[:lines_by_character]
    assert_empty report[:transcripts]
  end

  def test_generate_report_with_transcripts
    # Create a mock transcript
    transcripts_dir = File.join(@project_path, "transcripts")
    transcript_file = File.join(transcripts_dir, "scene1.txt")

    File.write(transcript_file, <<~TRANSCRIPT)
      Alice: Hello, how are you?
      Bob: I'm doing well, thanks!
      Alice: That's great to hear.
    TRANSCRIPT

    report = @producer.generate_report

    assert_equal 1, report[:total_scenes]
    assert_equal 3, report[:total_lines]
    assert_equal 2, report[:lines_by_character]["Alice"]
    assert_equal 1, report[:lines_by_character]["Bob"]
    assert_equal ["scene1.txt"], report[:transcripts]
  end

  def test_sanitize_filename
    # Test via create_character since sanitize_filename is private
    character_file = @producer.create_character("Alice O'Brien")
    assert_match(/alice_o_brien\.yml$/, character_file)
  end
end
