# frozen_string_literal: true

require "test_helper"

class HelpFormatterTest < Minitest::Test
  def test_print_comprehensive_help_outputs_content
    output = capture_io { WritersRoom::HelpFormatter.print_comprehensive_help }.first

    assert_includes output, "WRITERSROOM"
    assert_includes output, "USAGE:"
    assert_includes output, "GLOBAL OPTIONS:"
    assert_includes output, "COMMANDS:"
    assert_includes output, "EXAMPLES:"
    assert_includes output, "WORKFLOW:"
    assert_includes output, "CONFIGURATION:"
  end

  def test_includes_all_command_sections
    output = capture_io { WritersRoom::HelpFormatter.print_comprehensive_help }.first

    assert_includes output, "Producer Commands"
    assert_includes output, "Writer Commands"
    assert_includes output, "Character Commands"
    assert_includes output, "Scene Commands"
    assert_includes output, "Director Commands"
    assert_includes output, "Utility Commands"
  end

  def test_includes_key_commands
    output = capture_io { WritersRoom::HelpFormatter.print_comprehensive_help }.first

    assert_includes output, "init"
    assert_includes output, "config"
    assert_includes output, "produce"
    assert_includes output, "direct"
    assert_includes output, "write"
    assert_includes output, "character"
    assert_includes output, "scene"
    assert_includes output, "report"
    assert_includes output, "version"
    assert_includes output, "help"
  end

  def test_scene_file_references_md_format
    output = capture_io { WritersRoom::HelpFormatter.print_comprehensive_help }.first

    assert_includes output, "Scene file (.md)"
    refute_includes output, ".yml"
  end

  def test_includes_examples
    output = capture_io { WritersRoom::HelpFormatter.print_comprehensive_help }.first

    assert_includes output, "wr init"
    assert_includes output, "wr direct"
    assert_includes output, "wr produce"
    assert_includes output, "wr report"
  end

  def test_instance_and_class_method_produce_same_output
    class_output = capture_io { WritersRoom::HelpFormatter.print_comprehensive_help }.first
    instance_output = capture_io { WritersRoom::HelpFormatter.new.print_comprehensive_help }.first

    assert_equal class_output, instance_output
  end
end
