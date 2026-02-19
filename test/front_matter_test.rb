# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class FrontMatterTest < Minitest::Test
  def test_parse_with_front_matter
    content = <<~MD
      ---
      title: Test
      count: 42
      ---

      Body content here.
    MD

    result = WritersRoom::FrontMatter.parse(content)
    assert_equal({ title: "Test", count: 42 }, result[:metadata])
    assert_equal "Body content here.", result[:body]
  end

  def test_parse_without_front_matter
    content = "Just body content."

    result = WritersRoom::FrontMatter.parse(content)
    assert_equal({}, result[:metadata])
    assert_equal "Just body content.", result[:body]
  end

  def test_parse_with_symbolize_keys_false
    content = <<~MD
      ---
      title: Test
      ---

      Body.
    MD

    result = WritersRoom::FrontMatter.parse(content, symbolize_keys: false)
    assert_equal({ "title" => "Test" }, result[:metadata])
  end

  def test_parse_with_nested_metadata
    content = <<~MD
      ---
      name: Alex
      relationships:
        Tyler: "Rival"
        Marcus: "Friend"
      ---

      ## Personality

      Some text.
    MD

    result = WritersRoom::FrontMatter.parse(content)
    assert_equal "Alex", result[:metadata][:name]
    assert_equal "Rival", result[:metadata][:relationships][:Tyler]
    assert_includes result[:body], "## Personality"
  end

  def test_parse_with_arrays
    content = <<~MD
      ---
      characters:
        - Alice
        - Bob
      ---

      Scene body.
    MD

    result = WritersRoom::FrontMatter.parse(content)
    assert_equal %w[Alice Bob], result[:metadata][:characters]
  end

  def test_parse_empty_content
    result = WritersRoom::FrontMatter.parse("")
    assert_equal({}, result[:metadata])
    assert_equal "", result[:body]
  end

  def test_load_file
    Dir.mktmpdir("fm_test") do |dir|
      path = File.join(dir, "test.md")
      File.write(path, <<~MD)
        ---
        title: From File
        ---

        File body.
      MD

      result = WritersRoom::FrontMatter.load_file(path)
      assert_equal "From File", result[:metadata][:title]
      assert_equal "File body.", result[:body]
    end
  end

  def test_dump
    metadata = { "title" => "Test", "count" => 42 }
    body = "Some body text."

    result = WritersRoom::FrontMatter.dump(metadata, body)
    assert result.start_with?("---\n")
    assert_includes result, "title: Test"
    assert_includes result, "count: 42"
    assert_includes result, "Some body text."
  end

  def test_dump_empty_body
    result = WritersRoom::FrontMatter.dump({ "title" => "Test" }, "")
    assert result.start_with?("---\n")
    assert_includes result, "title: Test"
  end

  def test_roundtrip
    original_meta = { "name" => "Alex", "age" => 17 }
    original_body = "## Personality\n\nSome text here."

    dumped = WritersRoom::FrontMatter.dump(original_meta, original_body)
    parsed = WritersRoom::FrontMatter.parse(dumped, symbolize_keys: false)

    assert_equal original_meta, parsed[:metadata]
    assert_equal original_body, parsed[:body]
  end

  def test_parses_teen_play_character
    path = File.join(__dir__, "..", "projects", "teen_play", "characters", "alex.md")
    return skip("teen_play project not found") unless File.exist?(path)

    result = WritersRoom::FrontMatter.load_file(path)
    assert_equal "Alex", result[:metadata][:name]
    assert_equal 17, result[:metadata][:age]
    assert_includes result[:body], "## Personality"
    assert_includes result[:body], "## Voice Pattern"
    assert_includes result[:body], "## Current Arc"
  end

  def test_parses_teen_play_scene
    path = File.join(__dir__, "..", "projects", "teen_play", "scenes", "scene_01_gym_wars.md")
    return skip("teen_play project not found") unless File.exist?(path)

    result = WritersRoom::FrontMatter.load_file(path)
    assert_equal 1, result[:metadata][:scene_number]
    assert_equal "The Gym Wars", result[:metadata][:scene_name]
    assert_includes result[:metadata][:characters], "Marcus"
    assert_includes result[:body], "## Context"
  end
end
