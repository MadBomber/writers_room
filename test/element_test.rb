# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class ElementTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("element_test")
    @chars_dir = File.join(@temp_dir, "characters")
    FileUtils.mkdir_p(@chars_dir)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_create_element
    el = WritersRoom::Element.create(@chars_dir, "Alice Smith",
      metadata: { "personality" => "cheerful" },
      body: "A protagonist.")

    assert File.exist?(el.path)
    assert_equal "alice_smith", el.slug
    assert_equal "Alice Smith", el.name
    assert_equal "A protagonist.", el.body
  end

  def test_create_raises_if_exists
    WritersRoom::Element.create(@chars_dir, "Alice")

    assert_raises(WritersRoom::Error) do
      WritersRoom::Element.create(@chars_dir, "Alice")
    end
  end

  def test_load_element
    content = WritersRoom::FrontMatter.dump(
      { "name" => "Bob", "aliases" => ["Bobby", "Robert"] },
      "Bob is reliable."
    )
    path = File.join(@chars_dir, "bob.md")
    File.write(path, content)

    el = WritersRoom::Element.load(path)
    assert_equal "Bob", el.name
    assert_equal ["Bobby", "Robert"], el.aliases
    assert_equal "Bob is reliable.", el.body
  end

  def test_matches_name_by_slug
    el = WritersRoom::Element.create(@chars_dir, "Alice Smith")
    assert el.matches_name?("alice_smith")
  end

  def test_matches_name_by_name
    el = WritersRoom::Element.create(@chars_dir, "Alice Smith")
    assert el.matches_name?("Alice Smith")
    assert el.matches_name?("alice smith")
  end

  def test_matches_name_by_alias
    content = WritersRoom::FrontMatter.dump(
      { "name" => "James Morrison", "aliases" => ["Jim", "Detective Morrison"] },
      ""
    )
    path = File.join(@chars_dir, "james_morrison.md")
    File.write(path, content)

    el = WritersRoom::Element.load(path)
    assert el.matches_name?("Jim")
    assert el.matches_name?("Detective Morrison")
    refute el.matches_name?("Bob")
  end

  def test_save_roundtrip
    el = WritersRoom::Element.create(@chars_dir, "Carol",
      metadata: { "status" => "draft" },
      body: "Original body")

    el.metadata[:status] = "final"
    el.save

    reloaded = WritersRoom::Element.load(el.path)
    assert_equal "final", reloaded.status
  end

  def test_version_and_status_accessors
    content = WritersRoom::FrontMatter.dump(
      { "name" => "Ch1", "version" => 2, "status" => "revision", "based_on" => "ch1_v1.md" },
      ""
    )
    path = File.join(@chars_dir, "ch1.md")
    File.write(path, content)

    el = WritersRoom::Element.load(path)
    assert_equal 2, el.version
    assert_equal "revision", el.status
    assert_equal "ch1_v1.md", el.based_on
  end

  def test_to_h
    el = WritersRoom::Element.create(@chars_dir, "Dave")
    h = el.to_h
    assert_equal "dave", h[:slug]
    assert_equal "Dave", h[:name]
    assert_kind_of String, h[:path]
  end

  def test_sanitize
    assert_equal "hello_world", WritersRoom::Element.sanitize("Hello World!")
    assert_equal "o_brien", WritersRoom::Element.sanitize("O'Brien")
  end
end
