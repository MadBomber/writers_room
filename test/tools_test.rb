# frozen_string_literal: true

require "test_helper"

# Minimal mock robot for tool testing
class MockRobot
  attr_accessor :shared_memory, :display, :name, :last_message

  def initialize(name: "test_actor", shared_memory: nil, display: nil)
    @name = name
    @shared_memory = shared_memory || MockMemory.new
    @display = display || MockDisplay.new
    @last_message = nil
  end

  def send_message(to:, content:)
    @last_message = { to: to, content: content }
  end
end

# Minimal mock memory (mimics RobotLab::Memory key-value interface)
class MockMemory
  def initialize
    @store = {}
  end

  def get(key)
    @store[key]
  end

  def set(key, value)
    @store[key] = value
  end

  def key?(key)
    @store.key?(key)
  end

  def keys
    @store.keys
  end
end

# Minimal mock display (captures output for verification)
class MockDisplay
  attr_reader :dialogs, :memory_writes, :completions

  def initialize
    @dialogs = []
    @memory_writes = []
    @completions = []
  end

  def dialog(from, text, emotion: nil)
    @dialogs << { from: from, text: text, emotion: emotion }
  end

  def memory_write(writer, key)
    @memory_writes << { writer: writer, key: key }
  end

  def complete(who)
    @completions << who
  end
end

class SpeakToolTest < Minitest::Test
  def setup
    @memory = MockMemory.new
    @display = MockDisplay.new
    @robot = MockRobot.new(name: "alice", shared_memory: @memory, display: @display)
    @tool = WritersRoom::SpeakTool.new(robot: @robot)
  end

  def test_execute_records_dialog_in_memory
    @tool.execute(dialog: "Hello everyone!")

    history = @memory.get(:dialog_history)
    assert_equal 1, history.length
    assert_equal "alice", history.first[:from]
    assert_equal "Hello everyone!", history.first[:content]
  end

  def test_execute_records_emotion
    @tool.execute(dialog: "I can't believe it!", emotion: "shocked")

    history = @memory.get(:dialog_history)
    assert_equal "shocked", history.first[:emotion]
  end

  def test_execute_sends_bus_message
    @tool.execute(dialog: "Hey there")

    assert_equal :scene, @robot.last_message[:to]
    assert_equal "Hey there", @robot.last_message[:content]
  end

  def test_execute_updates_display
    @tool.execute(dialog: "Hi Bob", emotion: "friendly")

    assert_equal 1, @display.dialogs.length
    assert_equal "alice", @display.dialogs.first[:from]
    assert_equal "Hi Bob", @display.dialogs.first[:text]
    assert_equal "friendly", @display.dialogs.first[:emotion]
  end

  def test_execute_appends_to_existing_history
    @memory.set(:dialog_history, [{ from: "bob", content: "Hey", emotion: nil, timestamp: 0 }])
    @tool.execute(dialog: "Hey back!")

    history = @memory.get(:dialog_history)
    assert_equal 2, history.length
    assert_equal "bob", history.first[:from]
    assert_equal "alice", history.last[:from]
  end

  def test_execute_returns_confirmation
    result = @tool.execute(dialog: "Testing")
    assert_equal "You said: Testing", result
  end
end

class ReadMemoryToolTest < Minitest::Test
  def setup
    @memory = MockMemory.new
    @robot = MockRobot.new(shared_memory: @memory)
    @tool = WritersRoom::ReadMemoryTool.new(robot: @robot)
  end

  def test_reads_string_value
    @memory.set(:notes, "Some important note")
    result = @tool.execute(key: "notes")
    assert_equal "Some important note", result
  end

  def test_reads_array_as_json
    @memory.set(:dialog_history, [{ from: "alice", content: "Hi" }])
    result = @tool.execute(key: "dialog_history")
    assert_includes result, "alice"
    assert_includes result, "Hi"
  end

  def test_reads_hash_as_json
    @memory.set(:state, { mood: "tense", time: "evening" })
    result = @tool.execute(key: "state")
    assert_includes result, "tense"
    assert_includes result, "evening"
  end

  def test_unset_key_returns_message
    result = @tool.execute(key: "nonexistent")
    assert_equal "Key 'nonexistent' is not set yet.", result
  end

  def test_no_memory_returns_error
    @robot.shared_memory = nil
    result = @tool.execute(key: "anything")
    assert_equal "No shared memory available.", result
  end
end

class WriteMemoryToolTest < Minitest::Test
  def setup
    @memory = MockMemory.new
    @display = MockDisplay.new
    @robot = MockRobot.new(name: "bob", shared_memory: @memory, display: @display)
    @tool = WritersRoom::WriteMemoryTool.new(robot: @robot)
  end

  def test_writes_value_to_memory
    @tool.execute(key: "scene_state", value: "tense confrontation")
    assert_equal "tense confrontation", @memory.get(:scene_state)
  end

  def test_updates_display
    @tool.execute(key: "notes", value: "something important")
    assert_equal 1, @display.memory_writes.length
    assert_equal "bob", @display.memory_writes.first[:writer]
    assert_equal "notes", @display.memory_writes.first[:key]
  end

  def test_blocks_reserved_key_scene_complete
    result = @tool.execute(key: "scene_complete", value: "true")
    assert_includes result, "Cannot write to reserved key"
    assert_nil @memory.get(:scene_complete)
  end

  def test_blocks_reserved_key_dialog_history
    result = @tool.execute(key: "dialog_history", value: "hacked")
    assert_includes result, "Cannot write to reserved key"
    assert_nil @memory.get(:dialog_history)
  end

  def test_blocks_reserved_key_line_count
    result = @tool.execute(key: "line_count", value: "999")
    assert_includes result, "Cannot write to reserved key"
    assert_nil @memory.get(:line_count)
  end

  def test_allows_non_reserved_keys
    result = @tool.execute(key: "my_notes", value: "observation")
    assert_equal "Stored 'my_notes' in shared memory.", result
    assert_equal "observation", @memory.get(:my_notes)
  end

  def test_no_memory_returns_error
    @robot.shared_memory = nil
    result = @tool.execute(key: "notes", value: "test")
    assert_equal "No shared memory available.", result
  end
end

class ListMemoryToolTest < Minitest::Test
  def setup
    @memory = MockMemory.new
    @robot = MockRobot.new(shared_memory: @memory)
    @tool = WritersRoom::ListMemoryTool.new(robot: @robot)
  end

  def test_empty_memory
    result = @tool.execute
    assert_equal "Shared memory is empty.", result
  end

  def test_lists_keys
    @memory.set(:dialog_history, [])
    @memory.set(:notes, "test")
    result = @tool.execute
    assert_includes result, "dialog_history"
    assert_includes result, "notes"
  end

  def test_no_memory_returns_error
    @robot.shared_memory = nil
    result = @tool.execute
    assert_equal "No shared memory available.", result
  end
end

class MarkSceneCompleteToolTest < Minitest::Test
  def setup
    @memory = MockMemory.new
    @display = MockDisplay.new
    @robot = MockRobot.new(name: "alice", shared_memory: @memory, display: @display)
    @tool = WritersRoom::MarkSceneCompleteTool.new(robot: @robot)
  end

  def test_sets_scene_complete_flag
    @tool.execute
    assert @memory.get(:scene_complete)
  end

  def test_updates_display
    @tool.execute
    assert_equal 1, @display.completions.length
    assert_equal "alice", @display.completions.first
  end

  def test_returns_confirmation
    result = @tool.execute
    assert_equal "Scene marked as complete.", result
  end

  def test_no_memory_returns_error
    @robot.shared_memory = nil
    result = @tool.execute
    assert_equal "No shared memory available.", result
  end
end
