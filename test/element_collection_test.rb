# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class ElementCollectionTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("collection_test")
    @chars_dir = File.join(@temp_dir, "characters")
    FileUtils.mkdir_p(@chars_dir)
    @collection = WritersRoom::ElementCollection.new(@chars_dir, element_type: :character)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_empty_collection
    assert @collection.empty?
    assert_equal 0, @collection.count
    assert_equal [], @collection.all
    assert_equal [], @collection.list
  end

  def test_create_and_list
    @collection.create("Alice")
    @collection.create("Bob")

    assert_equal 2, @collection.count
    refute @collection.empty?

    names = @collection.list.map { |h| h[:name] }
    assert_includes names, "Alice"
    assert_includes names, "Bob"
  end

  def test_find_by_slug
    @collection.create("Alice Smith")

    el = @collection.find_by_slug("alice_smith")
    assert_equal "Alice Smith", el.name
  end

  def test_find_by_slug_returns_nil
    assert_nil @collection.find_by_slug("nonexistent")
  end

  def test_find_by_name_or_alias
    content = WritersRoom::FrontMatter.dump(
      { "name" => "James Morrison", "aliases" => ["Jim", "Detective Morrison"] },
      ""
    )
    File.write(File.join(@chars_dir, "james_morrison.md"), content)

    el = @collection.find_by_name_or_alias("Jim")
    assert_equal "James Morrison", el.name

    el2 = @collection.find_by_name_or_alias("Detective Morrison")
    assert_equal "James Morrison", el2.name
  end

  def test_search_returns_all_matches
    content1 = WritersRoom::FrontMatter.dump(
      { "name" => "Jim Baker", "aliases" => ["Jim"] }, "")
    content2 = WritersRoom::FrontMatter.dump(
      { "name" => "Jim Morrison", "aliases" => ["Jim"] }, "")

    File.write(File.join(@chars_dir, "jim_baker.md"), content1)
    File.write(File.join(@chars_dir, "jim_morrison.md"), content2)

    results = @collection.search("Jim")
    assert_equal 2, results.length
  end

  def test_slugs
    @collection.create("Alice")
    @collection.create("Bob")
    assert_equal ["alice", "bob"], @collection.slugs
  end

  def test_nonexistent_dir
    col = WritersRoom::ElementCollection.new("/nonexistent/dir")
    assert col.empty?
    assert_equal 0, col.count
    assert_equal [], col.all
  end

  def test_create_sets_element_type
    el = @collection.create("Carol")
    assert_equal "character", el.element_type
  end
end
