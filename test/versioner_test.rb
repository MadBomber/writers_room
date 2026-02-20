# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class VersionerTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("versioner_test")
    @chapters_dir = File.join(@temp_dir, "chapters")
    FileUtils.mkdir_p(@chapters_dir)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_no_versions_initially
    v = WritersRoom::Versioner.new(@chapters_dir, "chapter_01")
    assert_equal 0, v.version_count
    assert_equal [], v.versions
    assert_nil v.latest_version
  end

  def test_create_first_version
    v = WritersRoom::Versioner.new(@chapters_dir, "chapter_01")
    el = v.create_new_version(
      body: "It was a dark and stormy night.",
      metadata: { "name" => "Chapter 1" }
    )

    assert_equal 1, v.version_count
    assert_equal 1, el.version
    assert_equal "draft", el.status
    assert_equal "It was a dark and stormy night.", el.body
  end

  def test_create_sequential_versions
    v = WritersRoom::Versioner.new(@chapters_dir, "chapter_01")
    v.create_new_version(body: "First draft", metadata: { "name" => "Ch1" })
    el2 = v.create_new_version(
      body: "Revised draft",
      metadata: { "name" => "Ch1", "status" => "revision" },
      based_on: "chapter_01_v1.md"
    )

    assert_equal 2, v.version_count
    assert_equal 2, el2.version
    assert_equal "revision", el2.status
    assert_equal "chapter_01_v1.md", el2.based_on
  end

  def test_latest_version
    v = WritersRoom::Versioner.new(@chapters_dir, "chapter_01")
    v.create_new_version(body: "V1", metadata: { "name" => "Ch1" })
    v.create_new_version(body: "V2", metadata: { "name" => "Ch1" })

    assert_match(/chapter_01_v2\.md$/, v.latest_version)
  end

  def test_version_at
    v = WritersRoom::Versioner.new(@chapters_dir, "chapter_01")
    v.create_new_version(body: "V1", metadata: { "name" => "Ch1" })
    v.create_new_version(body: "V2", metadata: { "name" => "Ch1" })

    el = v.version_at(1)
    assert_equal 1, el.version

    assert_nil v.version_at(99)
  end

  def test_create_version_copies_body_from_based_on
    v = WritersRoom::Versioner.new(@chapters_dir, "chapter_01")
    v.create_new_version(body: "Original content", metadata: { "name" => "Ch1" })

    el2 = v.create_new_version(
      metadata: { "name" => "Ch1", "status" => "revision" },
      based_on: "chapter_01_v1.md"
    )

    assert_equal "Original content", el2.body
  end
end
