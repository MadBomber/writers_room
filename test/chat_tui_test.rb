# frozen_string_literal: true

require "test_helper"

class ChatTuiTest < Minitest::Test
  # Test ChatSession's command dispatch (the logic ChatTui delegates to)

  def setup
    # Stub robot so we don't need a real LLM
    @session = WritersRoom::ChatSession.allocate
    @session.instance_variable_set(:@context, { project_name: "Test Project", medium_label: "novel" })
    @session.instance_variable_set(:@messages, [])
    @session.instance_variable_set(:@project_path, nil)
    @session.instance_variable_set(:@logger, Logger.new(File::NULL))
  end

  # --- Exit Commands ---

  def test_exit_commands
    %w[exit quit q bye].each do |cmd|
      assert @session.exit_command?(cmd), "Expected '#{cmd}' to be an exit command"
    end
  end

  def test_non_exit_commands
    %w[help save summary hello].each do |cmd|
      refute @session.exit_command?(cmd), "Expected '#{cmd}' NOT to be an exit command"
    end
  end

  def test_exit_nil
    refute @session.exit_command?(nil)
  end

  # --- Command Dispatch ---

  def test_handle_help
    result = @session.handle_command("help")
    assert result[:handled]
    assert_includes result[:output], "Commands"
    assert_includes result[:output], "save"
  end

  def test_handle_context
    result = @session.handle_command("context")
    assert result[:handled]
    assert_includes result[:output], "Test Project"
  end

  def test_handle_summary
    result = @session.handle_command("summary")
    assert result[:handled]
    assert_equal :summary, result[:async]
  end

  def test_handle_clear
    @session.messages << { role: "user", content: "test" }
    result = @session.handle_command("clear")
    assert result[:handled]
    assert result[:clear_display]
    assert_empty @session.messages
  end

  def test_handle_save_with_args
    result = @session.handle_command("save character Alice")
    assert result[:handled]
    assert_equal :save, result[:async]
    assert_equal ["character", "Alice"], result[:args]
  end

  def test_handle_auto_save
    result = @session.handle_command("save")
    assert result[:handled]
    assert_equal :auto_save, result[:async]
  end

  def test_handle_unknown_command
    result = @session.handle_command("tell me about dogs")
    refute result[:handled]
  end

  # --- Text Helpers ---

  def test_help_text_contains_commands
    text = @session.help_text
    assert_includes text, "save"
    assert_includes text, "help"
    assert_includes text, "exit"
  end

  def test_context_text
    text = @session.context_text
    assert_includes text, "Test Project"
    assert_includes text, "novel"
  end

  def test_context_text_empty
    @session.instance_variable_set(:@context, {})
    assert_equal "", @session.context_text
  end

  def test_welcome_text
    text = @session.welcome_text
    assert_includes text, "WritersRoom"
    assert_includes text, "help"
  end

  def test_goodbye_text
    text = @session.goodbye_text
    assert_includes text, "ended"
    assert_includes text, "0 exchanges"
  end
end
