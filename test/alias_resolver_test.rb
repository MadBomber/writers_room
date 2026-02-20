# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class AliasResolverTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("resolver_test")
    @chars_dir = File.join(@temp_dir, "characters")
    @locs_dir = File.join(@temp_dir, "locations")
    FileUtils.mkdir_p(@chars_dir)
    FileUtils.mkdir_p(@locs_dir)

    @chars = WritersRoom::ElementCollection.new(@chars_dir, element_type: :character)
    @locs = WritersRoom::ElementCollection.new(@locs_dir, element_type: :location)
    @resolver = WritersRoom::AliasResolver.new([@chars, @locs])
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_resolve_unique_name
    @chars.create("Alice")
    el = @resolver.resolve("Alice")
    assert_equal "Alice", el.name
  end

  def test_resolve_returns_nil_for_unknown
    assert_nil @resolver.resolve("Nobody")
  end

  def test_resolve_raises_on_ambiguous
    content1 = WritersRoom::FrontMatter.dump(
      { "name" => "Jim Baker", "aliases" => ["Jim"] }, "")
    content2 = WritersRoom::FrontMatter.dump(
      { "name" => "Jim Morrison", "aliases" => ["Jim"] }, "")

    File.write(File.join(@chars_dir, "jim_baker.md"), content1)
    File.write(File.join(@chars_dir, "jim_morrison.md"), content2)

    error = assert_raises(WritersRoom::Error) do
      @resolver.resolve("Jim")
    end
    assert_match(/Ambiguous/, error.message)
  end

  def test_resolve_across_collections
    @chars.create("Alice")
    @locs.create("The Pub", metadata: { "description" => "A cozy pub" })

    assert_equal "Alice", @resolver.resolve("Alice").name
    assert_equal "The Pub", @resolver.resolve("The Pub").name
  end

  def test_find_all
    @chars.create("Alice")
    @locs.create("Alice's House")

    results = @resolver.find_all("Alice")
    assert_equal 1, results.length  # only exact name match
  end

  def test_resolvable
    @chars.create("Alice")
    assert @resolver.resolvable?("Alice")
    refute @resolver.resolvable?("Nobody")
  end

  def test_add_collection
    new_dir = File.join(@temp_dir, "arcs")
    FileUtils.mkdir_p(new_dir)
    arcs = WritersRoom::ElementCollection.new(new_dir, element_type: :arc)
    arcs.create("Redemption")

    refute @resolver.resolvable?("Redemption")
    @resolver.add_collection(arcs)
    assert @resolver.resolvable?("Redemption")
  end
end
