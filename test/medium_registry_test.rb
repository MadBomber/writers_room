# frozen_string_literal: true

require "test_helper"

class MediumRegistryTest < Minitest::Test
  def setup
    WritersRoom::MediumRegistry.reset!
  end

  def test_find_dialog
    medium = WritersRoom::MediumRegistry.find(:dialog)

    assert_instance_of WritersRoom::Medium, medium
    assert_equal :dialog, medium.id
    assert_equal "Dialog Generation", medium.label
  end

  def test_find_novel
    medium = WritersRoom::MediumRegistry.find(:novel)

    assert_equal :novel, medium.id
    assert_equal "Novel", medium.label
  end

  def test_find_with_string_key
    medium = WritersRoom::MediumRegistry.find("novel")
    assert_equal :novel, medium.id
  end

  def test_find_unknown_raises_error
    error = assert_raises(WritersRoom::Error) do
      WritersRoom::MediumRegistry.find(:nonexistent)
    end
    assert_match(/Unknown medium/, error.message)
  end

  def test_all_returns_array_of_media
    all = WritersRoom::MediumRegistry.all

    assert_instance_of Array, all
    assert all.all? { |m| m.is_a?(WritersRoom::Medium) }
  end

  def test_ids_returns_all_medium_symbols
    ids = WritersRoom::MediumRegistry.ids

    assert_includes ids, :dialog
    assert_includes ids, :novel
    assert_includes ids, :novella
    assert_includes ids, :short_story
    assert_includes ids, :screenplay
    assert_includes ids, :stage_play
    assert_includes ids, :tv_series
    assert_includes ids, :radio_play
    assert_includes ids, :documentary
    assert_equal 9, ids.count
  end

  def test_dialog_scaffolded_dirs_match_current_behavior
    dialog = WritersRoom::MediumRegistry.find(:dialog)
    assert_equal %w[characters scenes transcripts arcs], dialog.scaffolded_dirs
  end

  def test_novel_scaffolded_dirs
    novel = WritersRoom::MediumRegistry.find(:novel)
    expected = %w[characters relationships arcs settings locations
                  research timeline backstory chapters parts transcripts]
    assert_equal expected, novel.scaffolded_dirs
  end

  def test_novel_universal_elements
    novel = WritersRoom::MediumRegistry.find(:novel)
    assert_includes novel.universal_elements, :characters
    assert_includes novel.universal_elements, :story
    assert_includes novel.universal_elements, :theme
    assert_includes novel.universal_elements, :point_of_view
  end

  def test_novel_specific_elements
    novel = WritersRoom::MediumRegistry.find(:novel)
    assert novel.specific_elements.key?("chapters")
    assert novel.specific_elements.key?("parts")
    assert novel.specific_elements.key?("prologue")
    assert novel.specific_elements.key?("epilogue")
  end

  def test_dialog_workflows
    dialog = WritersRoom::MediumRegistry.find(:dialog)
    assert_includes dialog.workflows, :develop_concept
    assert_includes dialog.workflows, :produce
  end

  def test_novel_statuses
    novel = WritersRoom::MediumRegistry.find(:novel)
    assert_equal %w[outline draft revision final], novel.statuses
  end

  def test_short_story_scaffolded_dirs
    short_story = WritersRoom::MediumRegistry.find(:short_story)
    assert_equal "Short Story", short_story.label
    assert_equal %w[characters settings scenes drafts transcripts], short_story.scaffolded_dirs
    refute_includes short_story.universal_elements, :arcs
    refute_includes short_story.universal_elements, :relationships
  end

  def test_novella_scaffolded_dirs
    novella = WritersRoom::MediumRegistry.find(:novella)
    assert_equal "Novella", novella.label
    assert_includes novella.scaffolded_dirs, "chapters"
    refute_includes novella.scaffolded_dirs, "parts"
    assert_includes novella.universal_elements, :arcs
  end

  def test_reset_clears_cache
    WritersRoom::MediumRegistry.find(:dialog)
    WritersRoom::MediumRegistry.reset!

    # Should reload without error
    medium = WritersRoom::MediumRegistry.find(:dialog)
    assert_equal :dialog, medium.id
  end
end
