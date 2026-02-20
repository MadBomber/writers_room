# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class ProjectMetadataTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("pm_test")
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
  end

  def test_path_points_to_project_md
    pm = WritersRoom::ProjectMetadata.new(@temp_dir)
    assert_equal File.join(@temp_dir, "project.md"), pm.path
  end

  def test_loads_defaults_when_no_file_exists
    pm = WritersRoom::ProjectMetadata.new(@temp_dir)

    assert_equal "", pm.name
  end

  def test_create_class_method
    pm = WritersRoom::ProjectMetadata.create(@temp_dir, name: "My Show", concept: "A drama")

    assert File.exist?(pm.path)
    assert_equal "My Show", pm.name
    assert_equal "A drama", pm.concept
  end

  def test_create_saves_to_disk
    WritersRoom::ProjectMetadata.create(@temp_dir, name: "Test", concept: "Concept text")

    # Reload from disk
    pm = WritersRoom::ProjectMetadata.new(@temp_dir)
    assert_equal "Test", pm.name
  end

  def test_save_and_reload
    pm = WritersRoom::ProjectMetadata.new(@temp_dir)
    pm.data["name"] = "Saved Project"
    pm.data["concept"] = "Some concept"
    pm.save

    reloaded = WritersRoom::ProjectMetadata.new(@temp_dir)
    assert_equal "Saved Project", reloaded.name
  end

  def test_name_setter
    pm = WritersRoom::ProjectMetadata.create(@temp_dir, name: "Original")
    pm.name = "Updated"

    reloaded = WritersRoom::ProjectMetadata.new(@temp_dir)
    assert_equal "Updated", reloaded.name
  end

  def test_concept_setter
    pm = WritersRoom::ProjectMetadata.create(@temp_dir, name: "Test")
    pm.concept = "New concept"

    reloaded = WritersRoom::ProjectMetadata.new(@temp_dir)
    assert_equal "New concept", reloaded.concept
  end

  def test_add_story_arc
    pm = WritersRoom::ProjectMetadata.create(@temp_dir, name: "Test")

    arc = { "name" => "Act 1", "description" => "The beginning" }
    pm.add_story_arc(arc)

    assert pm.story_arcs.any? { |a| a["name"] == "Act 1" }

    # Verify persisted
    reloaded = WritersRoom::ProjectMetadata.new(@temp_dir)
    assert reloaded.story_arcs.any? { |a| a["name"] == "Act 1" }
  end

  def test_add_multiple_story_arcs
    pm = WritersRoom::ProjectMetadata.create(@temp_dir, name: "Test")
    initial_count = pm.story_arcs.length

    pm.add_story_arc({ "name" => "Act 1" })
    pm.add_story_arc({ "name" => "Act 2" })
    pm.add_story_arc({ "name" => "Act 3" })

    assert_equal initial_count + 3, pm.story_arcs.length
  end

  def test_add_timeline_entry
    pm = WritersRoom::ProjectMetadata.create(@temp_dir, name: "Test")

    entry = { "week" => 1, "event" => "Series premiere" }
    pm.add_timeline_entry(entry)

    assert pm.timeline.any? { |e| e["event"] == "Series premiere" }

    reloaded = WritersRoom::ProjectMetadata.new(@temp_dir)
    assert reloaded.timeline.any? { |e| e["event"] == "Series premiere" }
  end

  def test_loads_from_md_front_matter
    content = WritersRoom::FrontMatter.dump(
      { "name" => "From MD", "concept" => "Test concept", "story_arcs" => [], "timeline" => [] },
      "## Description\n\nDetailed info here."
    )
    File.write(File.join(@temp_dir, "project.md"), content)

    pm = WritersRoom::ProjectMetadata.new(@temp_dir)
    assert_equal "From MD", pm.name
  end

  def test_concept_from_front_matter
    content = WritersRoom::FrontMatter.dump(
      { "name" => "Test", "concept" => "Explicit concept" },
      ""
    )
    File.write(File.join(@temp_dir, "project.md"), content)

    pm = WritersRoom::ProjectMetadata.new(@temp_dir)
    assert_equal "Explicit concept", pm.concept
  end

  def test_data_hash_accessible
    pm = WritersRoom::ProjectMetadata.create(@temp_dir, name: "Test")
    assert_instance_of Hash, pm.data
    assert_equal "Test", pm.data["name"]
  end

  def test_save_returns_true_on_success
    pm = WritersRoom::ProjectMetadata.new(@temp_dir)
    assert pm.save
  end

  def test_default_metadata_has_created_at
    pm = WritersRoom::ProjectMetadata.new(@temp_dir)
    refute_nil pm.data["created_at"]
  end

  def test_save_creates_directory_if_needed
    nested = File.join(@temp_dir, "deep", "nested")
    pm = WritersRoom::ProjectMetadata.new(nested)
    pm.data["name"] = "Nested"
    pm.save

    assert File.exist?(File.join(nested, "project.md"))
  end

  def test_concept_getter_with_no_data
    pm = WritersRoom::ProjectMetadata.new(@temp_dir)
    # Should return empty string, not nil
    assert_kind_of String, pm.concept
  end

  def test_story_arcs_with_no_data
    pm = WritersRoom::ProjectMetadata.new(@temp_dir)
    assert_kind_of Array, pm.story_arcs
  end

  def test_timeline_with_no_data
    pm = WritersRoom::ProjectMetadata.new(@temp_dir)
    assert_kind_of Array, pm.timeline
  end

  def test_roundtrip_preserves_name
    WritersRoom::ProjectMetadata.create(@temp_dir, name: "Roundtrip Test", concept: "A concept")
    reloaded = WritersRoom::ProjectMetadata.new(@temp_dir)
    assert_equal "Roundtrip Test", reloaded.name
  end
end
