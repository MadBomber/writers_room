# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class DisplayTest < Minitest::Test
  def setup
    @display = WritersRoom::Display.new(color: false)
  end

  def test_dialog_outputs_character_line
    output = capture_io { @display.dialog("Alice", "Hello!") }.first
    assert_equal "Alice: Hello!\n", output
  end

  def test_dialog_with_emotion
    output = capture_io { @display.dialog("Bob", "Wow!", emotion: "surprised") }.first
    assert_equal "Bob [surprised]: Wow!\n", output
  end

  def test_director_note_output
    output = capture_io { @display.director_note("SCENE BEGINS") }.first
    assert_equal "[DIRECTOR: SCENE BEGINS]\n", output
  end

  def test_scene_header_includes_metadata
    info = {
      scene_number: 1,
      scene_name: "Test Scene",
      location: "Coffee Shop",
      characters: ["Alice", "Bob"]
    }
    output = capture_io { @display.scene_header(info) }.first
    assert_includes output, "SCENE 1: Test Scene"
    assert_includes output, "Location: Coffee Shop"
    assert_includes output, "Characters: Alice, Bob"
  end

  def test_scene_header_with_string_keys
    info = {
      "scene_number" => 2,
      "scene_name" => "Scene Two",
      "location" => "Park",
      "characters" => ["Charlie"]
    }
    output = capture_io { @display.scene_header(info) }.first
    assert_includes output, "SCENE 2: Scene Two"
    assert_includes output, "Location: Park"
  end

  def test_info_output
    output = capture_io { @display.info("Some info message") }.first
    assert_equal "Some info message\n", output
  end

  def test_separator_output
    output = capture_io { @display.separator }.first
    assert_equal "-" * 60 + "\n", output
  end

  def test_banner_output
    output = capture_io { @display.banner("Welcome") }.first
    assert_includes output, "=" * 60
    assert_includes output, "Welcome"
  end

  def test_memory_write_output
    output = capture_io { @display.memory_write("alice", "notes") }.first
    assert_equal "[MEMORY] alice wrote :notes\n", output
  end

  def test_complete_output
    output = capture_io { @display.complete("bob") }.first
    assert_equal "[COMPLETE] Scene marked complete by bob\n", output
  end

  def test_color_mode_adds_ansi_codes
    colored_display = WritersRoom::Display.new(color: true)
    output = capture_io { colored_display.info("colored") }.first
    assert_includes output, "\e["
    assert_includes output, "colored"
  end

  def test_no_color_mode_has_no_ansi
    output = capture_io { @display.info("plain text") }.first
    refute_includes output, "\e["
  end

  def test_character_colors_are_consistent
    colored_display = WritersRoom::Display.new(color: true)
    out1 = capture_io { colored_display.dialog("Alice", "First") }.first
    out2 = capture_io { colored_display.dialog("Alice", "Second") }.first

    # Extract the color code (everything before "Alice")
    color1 = out1.split("Alice").first
    color2 = out2.split("Alice").first
    assert_equal color1, color2
  end

  def test_different_characters_get_different_colors
    colored_display = WritersRoom::Display.new(color: true)
    out1 = capture_io { colored_display.dialog("Alice", "Hi") }.first
    out2 = capture_io { colored_display.dialog("Bob", "Hi") }.first

    color1 = out1.split("Alice").first
    color2 = out2.split("Bob").first
    refute_equal color1, color2
  end

  def test_log_file_receives_entries
    Dir.mktmpdir("display_test") do |dir|
      log_path = File.join(dir, "test.log")
      display = WritersRoom::Display.new(log_path: log_path, color: false)

      capture_io do
        display.dialog("Alice", "Hello")
        display.director_note("CUT!")
      end

      display.close

      log_content = File.read(log_path)
      assert_includes log_content, "Alice: Hello"
      assert_includes log_content, "[DIRECTOR: CUT!]"
    end
  end

  def test_incoming_logs_but_does_not_print
    Dir.mktmpdir("display_test") do |dir|
      log_path = File.join(dir, "test.log")
      display = WritersRoom::Display.new(log_path: log_path, color: false)

      output = capture_io { display.incoming("bob", "alice", "Hey there") }.first
      display.close

      assert_empty output
      log_content = File.read(log_path)
      assert_includes log_content, "[alice -> bob]"
      assert_includes log_content, "Hey there"
    end
  end

  def test_broadcast_delegates_to_dialog
    output = capture_io { @display.broadcast("Alice", "Everyone listen!") }.first
    assert_equal "Alice: Everyone listen!\n", output
  end

  def test_stats_output
    stats = {
      total_lines: 10,
      lines_by_character: { "Alice" => 6, "Bob" => 4 }
    }
    output = capture_io { @display.stats(stats) }.first
    assert_includes output, "Total lines: 10"
    assert_includes output, "Alice: 6"
    assert_includes output, "Bob: 4"
  end

  def test_close_without_log_file
    # Should not raise
    @display.close
  end
end
