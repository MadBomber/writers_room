# frozen_string_literal: true

require "test_helper"

class RoomTest < Minitest::Test
  def setup
    @display = WritersRoom::Display.new(color: false)
    @scene_info = {
      scene_name: "Test Scene",
      scene_number: 1,
      location: "Test Location",
      characters: ["Alice", "Bob"]
    }
  end

  def test_initializes_with_bus_and_memory
    config = RobotLab::RunConfig.new(model: "test")
    room = WritersRoom::Room.new(display: @display, config: config, scene_info: @scene_info)

    assert_instance_of TypedBus::MessageBus, room.bus
    assert_instance_of RobotLab::Memory, room.memory
    assert_empty room.actors
  end

  def test_stores_scene_info
    config = RobotLab::RunConfig.new(model: "test")
    room = WritersRoom::Room.new(display: @display, config: config, scene_info: @scene_info)

    assert_equal "Test Scene", room.scene_info[:scene_name]
    assert_equal ["Alice", "Bob"], room.scene_info[:characters]
  end

  def test_assemble_transcript_returns_empty_when_no_dialog
    config = RobotLab::RunConfig.new(model: "test")
    room = WritersRoom::Room.new(display: @display, config: config, scene_info: @scene_info)

    assert_empty room.assemble_transcript
  end

  def test_assemble_transcript_returns_dialog_from_memory
    config = RobotLab::RunConfig.new(model: "test")
    room = WritersRoom::Room.new(display: @display, config: config, scene_info: @scene_info)

    dialog = [
      { from: "alice", content: "Hello", emotion: nil, timestamp: 1 },
      { from: "bob", content: "Hi there", emotion: "friendly", timestamp: 2 }
    ]
    room.memory.set(:dialog_history, dialog)

    transcript = room.assemble_transcript
    assert_equal 2, transcript.length
    assert_equal "alice", transcript.first[:from]
    assert_equal "Hi there", transcript.last[:content]
  end

  def test_wait_for_completion_returns_true_when_scene_complete
    config = RobotLab::RunConfig.new(model: "test")
    room = WritersRoom::Room.new(display: @display, config: config, scene_info: @scene_info)

    room.memory.set(:scene_complete, true)

    result = room.wait_for_completion(timeout: 5, max_lines: 50, poll_interval: 0.1)
    assert result
  end

  def test_wait_for_completion_returns_true_when_max_lines_reached
    config = RobotLab::RunConfig.new(model: "test")
    room = WritersRoom::Room.new(display: @display, config: config, scene_info: @scene_info)

    dialog = Array.new(10) { |i| { from: "actor", content: "Line #{i}" } }
    room.memory.set(:dialog_history, dialog)

    result = room.wait_for_completion(timeout: 5, max_lines: 10, poll_interval: 0.1)
    assert result
    assert room.memory.get(:scene_complete)
  end

  def test_wait_for_completion_returns_false_on_timeout
    config = RobotLab::RunConfig.new(model: "test")
    room = WritersRoom::Room.new(display: @display, config: config, scene_info: @scene_info)

    result = room.wait_for_completion(timeout: 0.2, max_lines: 50, poll_interval: 0.1, heartbeat_interval: 999)
    refute result
  end

  def test_shutdown_clears_actors
    config = RobotLab::RunConfig.new(model: "test")
    room = WritersRoom::Room.new(display: @display, config: config, scene_info: @scene_info)

    room.shutdown
    assert_empty room.actors
  end
end
