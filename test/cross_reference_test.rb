# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class CrossReferenceTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("xref_test")
    @project = File.join(@temp_dir, "test_project")
    WritersRoom::Producer.create_project(@project, name: "test", concept: "test", medium: "dialog")
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_scan_empty_project
    xref = WritersRoom::CrossReference.new(@project)
    refs = xref.scan
    assert_equal({}, refs)
  end

  def test_scan_finds_references
    chars_dir = File.join(@project, "characters")
    scenes_dir = File.join(@project, "scenes")

    File.write(File.join(chars_dir, "alice.md"),
      WritersRoom::FrontMatter.dump({ "name" => "Alice", "aliases" => [] }, "Alice is the hero."))

    File.write(File.join(chars_dir, "bob.md"),
      WritersRoom::FrontMatter.dump({ "name" => "Bob", "aliases" => [] }, "Bob is Alice's friend."))

    File.write(File.join(scenes_dir, "opening.md"),
      WritersRoom::FrontMatter.dump({ "name" => "Opening" }, "Alice and Bob meet at the cafe."))

    xref = WritersRoom::CrossReference.new(@project)
    xref.scan

    # Bob's body mentions Alice
    assert_includes xref.references_for("bob"), "alice"
    # Opening mentions both
    assert_includes xref.references_for("opening"), "alice"
    assert_includes xref.references_for("opening"), "bob"
  end

  def test_referenced_by
    chars_dir = File.join(@project, "characters")

    File.write(File.join(chars_dir, "alice.md"),
      WritersRoom::FrontMatter.dump({ "name" => "Alice" }, ""))
    File.write(File.join(chars_dir, "bob.md"),
      WritersRoom::FrontMatter.dump({ "name" => "Bob" }, "Bob admires Alice greatly."))

    xref = WritersRoom::CrossReference.new(@project)
    xref.scan

    assert_includes xref.referenced_by("alice"), "bob"
  end

  def test_graph
    chars_dir = File.join(@project, "characters")

    File.write(File.join(chars_dir, "alice.md"),
      WritersRoom::FrontMatter.dump({ "name" => "Alice" }, ""))
    File.write(File.join(chars_dir, "bob.md"),
      WritersRoom::FrontMatter.dump({ "name" => "Bob" }, "Bob knows Alice well."))

    xref = WritersRoom::CrossReference.new(@project)
    xref.scan

    graph = xref.graph
    assert_includes graph[:nodes], "bob"
    assert_includes graph[:nodes], "alice"
    assert graph[:edges].any? { |e| e[:from] == "bob" && e[:to] == "alice" }
  end

  def test_alias_references
    chars_dir = File.join(@project, "characters")

    File.write(File.join(chars_dir, "james_morrison.md"),
      WritersRoom::FrontMatter.dump(
        { "name" => "James Morrison", "aliases" => ["Jim", "Detective Morrison"] }, ""))

    File.write(File.join(chars_dir, "carol.md"),
      WritersRoom::FrontMatter.dump(
        { "name" => "Carol" }, "Carol called Detective Morrison for help."))

    xref = WritersRoom::CrossReference.new(@project)
    xref.scan

    assert_includes xref.references_for("carol"), "james_morrison"
  end
end
