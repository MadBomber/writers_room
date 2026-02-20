# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class FormattersTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("formatter_test")
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_base_formatter_format
    project = File.join(@temp_dir, "base_project")
    WritersRoom::Producer.create_project(project, name: "Test", concept: "A test", medium: "dialog")

    formatter = WritersRoom::Formatters::BaseFormatter.new(project)
    output = formatter.format

    assert_match(/Test/, output)
    assert_match(/Dialog Generation/, output)
  end

  def test_base_formatter_export
    project = File.join(@temp_dir, "export_project")
    WritersRoom::Producer.create_project(project, name: "Test", concept: "A test", medium: "dialog")

    formatter = WritersRoom::Formatters::BaseFormatter.new(project)
    output_path = File.join(@temp_dir, "output.md")
    formatter.export(output_path)

    assert File.exist?(output_path)
    assert_match(/Test/, File.read(output_path))
  end

  def test_novel_formatter_with_chapters
    project = File.join(@temp_dir, "novel_project")
    WritersRoom::Producer.create_project(project, name: "My Novel", concept: "A story", medium: "novel")

    chapters_dir = File.join(project, "chapters")
    File.write(File.join(chapters_dir, "ch01.md"),
      WritersRoom::FrontMatter.dump(
        { "name" => "The Beginning", "chapter_number" => 1 },
        "It was a dark and stormy night."))
    File.write(File.join(chapters_dir, "ch02.md"),
      WritersRoom::FrontMatter.dump(
        { "name" => "The Journey", "chapter_number" => 2 },
        "They set off at dawn."))

    formatter = WritersRoom::Formatters::NovelFormatter.new(project)
    output = formatter.format

    assert_match(/Table of Contents/, output)
    assert_match(/The Beginning/, output)
    assert_match(/The Journey/, output)
    assert_match(/Chapter 1/, output)
    assert_match(/dark and stormy/, output)
  end

  def test_transcript_formatter
    project = File.join(@temp_dir, "dialog_project")
    WritersRoom::Producer.create_project(project, name: "Dialog", concept: "test", medium: "dialog")

    transcripts_dir = File.join(project, "transcripts")
    File.write(File.join(transcripts_dir, "scene1.txt"), "Alice: Hello\nBob: Hi")

    formatter = WritersRoom::Formatters::TranscriptFormatter.new(project)
    output = formatter.format

    assert_match(/Alice: Hello/, output)
    assert_match(/scene1\.txt/, output)
  end

  def test_screenplay_formatter
    project = File.join(@temp_dir, "screenplay_project")
    WritersRoom::Producer.create_project(project, name: "My Script", concept: "test", medium: "screenplay")

    scenes_dir = File.join(project, "scenes")
    File.write(File.join(scenes_dir, "opening.md"),
      WritersRoom::FrontMatter.dump(
        { "name" => "Opening", "location" => "INT. OFFICE - DAY" },
        "A busy office. Phones ringing."))

    formatter = WritersRoom::Formatters::ScreenplayFormatter.new(project)
    output = formatter.format

    assert_match(/MY SCRIPT/, output)
    assert_match(/INT\. OFFICE - DAY/, output)
  end
end
