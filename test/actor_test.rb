# frozen_string_literal: true

require "test_helper"

class ActorTest < Minitest::Test
  # Use a model that RubyLLM recognizes (no actual API calls are made)
  TEST_MODEL = "gpt-4o-mini"

  def setup
    @bus = TypedBus::MessageBus.new
    @bus.add_channel(:scene)
    @memory = RobotLab::Memory.new(enable_cache: false)
    @display = WritersRoom::Display.new(color: false)
    @config = RobotLab::RunConfig.new(model: TEST_MODEL)

    @character_info = {
      name: "Alice",
      age: 25,
      personality: "cheerful",
      voice_pattern: "casual and upbeat",
      background: "A college student",
      current_arc: "Finding her confidence",
      relationships: { "Bob" => "friend", "Carol" => "rival" }
    }

    @scene_info = {
      scene_name: "Coffee Shop",
      scene_number: 1,
      location: "Downtown Cafe",
      characters: ["Alice", "Bob"],
      objectives: ["Have a conversation about the future"],
      concept: "A story about friendship"
    }
  end

  def test_initializes_with_character_name
    actor = build_actor
    assert_equal "alice", actor.name
    assert_equal "Alice", actor.character_name
  end

  def test_stores_character_info
    actor = build_actor
    assert_equal @character_info, actor.character_info
  end

  def test_stores_scene_info
    actor = build_actor
    assert_equal @scene_info, actor.scene_info
  end

  def test_assigns_shared_memory
    actor = build_actor
    assert_same @memory, actor.shared_memory
  end

  def test_assigns_display
    actor = build_actor
    assert_same @display, actor.display
  end

  def test_raises_without_character_name
    bad_info = { personality: "cheerful" }

    assert_raises(ArgumentError) do
      WritersRoom::Actor.new(
        character_info: bad_info,
        scene_info: @scene_info,
        bus: @bus,
        config: @config
      )
    end
  end

  def test_handles_string_key_character_name
    info = { "name" => "Bob", "personality" => "sarcastic" }
    actor = WritersRoom::Actor.new(
      character_info: info,
      scene_info: @scene_info,
      bus: @bus,
      config: @config
    )
    assert_equal "Bob", actor.character_name
    assert_equal "bob", actor.name
  end

  def test_name_with_spaces_becomes_underscored
    info = { name: "Mary Jane", personality: "kind" }
    actor = WritersRoom::Actor.new(
      character_info: info,
      scene_info: @scene_info,
      bus: @bus,
      config: @config
    )
    assert_equal "mary_jane", actor.name
  end

  def test_build_template_context_character_fields
    actor = build_actor
    ctx = actor.send(:build_template_context)

    assert_equal "Alice", ctx[:character_name]
    assert_equal 25, ctx[:age]
    assert_equal "cheerful", ctx[:personality]
    assert_equal "casual and upbeat", ctx[:voice_pattern]
    assert_equal "A college student", ctx[:background]
    assert_equal "Finding her confidence", ctx[:current_arc]
  end

  def test_build_template_context_scene_fields
    actor = build_actor
    ctx = actor.send(:build_template_context)

    assert_equal "Coffee Shop", ctx[:scene_name]
    assert_equal 1, ctx[:scene_number]
    assert_equal "Downtown Cafe", ctx[:location]
    assert_equal "Alice, Bob", ctx[:characters_present]
    assert_equal "A story about friendship", ctx[:project_concept]
  end

  def test_build_template_context_objectives_array
    actor = build_actor
    ctx = actor.send(:build_template_context)

    assert_equal "Have a conversation about the future", ctx[:objectives]
  end

  def test_build_template_context_objectives_string
    @scene_info[:objectives] = "Single objective"
    actor = build_actor
    ctx = actor.send(:build_template_context)

    assert_equal "Single objective", ctx[:objectives]
  end

  def test_extract_personality_from_top_level
    actor = build_actor
    assert_equal "cheerful", actor.send(:extract_personality)
  end

  def test_extract_personality_from_traits_hash
    info = {
      name: "Bob",
      traits: { personality: "sarcastic", speaking_style: "dry" }
    }
    actor = WritersRoom::Actor.new(
      character_info: info,
      scene_info: @scene_info,
      bus: @bus,
      config: @config
    )
    assert_equal "sarcastic", actor.send(:extract_personality)
  end

  def test_extract_personality_from_traits_string_keys
    info = {
      name: "Bob",
      "traits" => { "personality" => "witty" }
    }
    actor = WritersRoom::Actor.new(
      character_info: info,
      scene_info: @scene_info,
      bus: @bus,
      config: @config
    )
    assert_equal "witty", actor.send(:extract_personality)
  end

  def test_extract_personality_returns_empty_when_missing
    info = { name: "Bob" }
    actor = WritersRoom::Actor.new(
      character_info: info,
      scene_info: @scene_info,
      bus: @bus,
      config: @config
    )
    assert_equal "", actor.send(:extract_personality)
  end

  def test_extract_voice_pattern_prefers_voice_pattern
    actor = build_actor
    assert_equal "casual and upbeat", actor.send(:extract_voice_pattern)
  end

  def test_extract_voice_pattern_falls_back_to_speaking_style
    info = { name: "Bob", speaking_style: "formal" }
    actor = WritersRoom::Actor.new(
      character_info: info,
      scene_info: @scene_info,
      bus: @bus,
      config: @config
    )
    assert_equal "formal", actor.send(:extract_voice_pattern)
  end

  def test_extract_voice_pattern_returns_empty_when_missing
    info = { name: "Bob" }
    actor = WritersRoom::Actor.new(
      character_info: info,
      scene_info: @scene_info,
      bus: @bus,
      config: @config
    )
    assert_equal "", actor.send(:extract_voice_pattern)
  end

  def test_extract_background
    actor = build_actor
    assert_equal "A college student", actor.send(:extract_background)
  end

  def test_extract_background_returns_empty_when_missing
    info = { name: "Bob" }
    actor = WritersRoom::Actor.new(
      character_info: info,
      scene_info: @scene_info,
      bus: @bus,
      config: @config
    )
    assert_equal "", actor.send(:extract_background)
  end

  def test_extract_current_arc
    actor = build_actor
    assert_equal "Finding her confidence", actor.send(:extract_current_arc)
  end

  def test_extract_current_arc_returns_empty_when_missing
    info = { name: "Bob" }
    actor = WritersRoom::Actor.new(
      character_info: info,
      scene_info: @scene_info,
      bus: @bus,
      config: @config
    )
    assert_equal "", actor.send(:extract_current_arc)
  end

  def test_format_relationships_hash
    actor = build_actor
    result = actor.send(:format_relationships)

    assert_includes result, "- Bob: friend"
    assert_includes result, "- Carol: rival"
  end

  def test_format_relationships_string
    info = { name: "Bob", relationships: "Complex web of alliances" }
    actor = WritersRoom::Actor.new(
      character_info: info,
      scene_info: @scene_info,
      bus: @bus,
      config: @config
    )
    assert_equal "Complex web of alliances", actor.send(:format_relationships)
  end

  def test_format_relationships_missing
    info = { name: "Bob" }
    actor = WritersRoom::Actor.new(
      character_info: info,
      scene_info: @scene_info,
      bus: @bus,
      config: @config
    )
    assert_equal "No specific relationships defined", actor.send(:format_relationships)
  end

  def test_heartbeat_message_detection
    actor = build_actor
    assert actor.send(:heartbeat_message?, "[ROOM STATUS] 5/50 lines spoken. 45 remaining.")
    refute actor.send(:heartbeat_message?, "Hello everyone!")
    refute actor.send(:heartbeat_message?, nil)
    refute actor.send(:heartbeat_message?, "")
  end

  def test_build_turn_prompt_basic
    actor = build_actor
    message = OpenStruct.new(from: "bob", content: "Hey Alice!")

    prompt = actor.send(:build_turn_prompt, message)
    assert_includes prompt, "[bob]: Hey Alice!"
  end

  def test_build_turn_prompt_with_dialog_history
    actor = build_actor
    @memory.set(:dialog_history, [
      { from: "bob", content: "Hey", emotion: nil },
      { from: "alice", content: "Hi there", emotion: "friendly" }
    ])

    message = OpenStruct.new(from: "bob", content: "How are you?")
    prompt = actor.send(:build_turn_prompt, message)

    assert_includes prompt, "[bob]: How are you?"
    assert_includes prompt, "[Recent dialog]"
    assert_includes prompt, "bob: Hey"
    assert_includes prompt, "alice [friendly]: Hi there"
  end

  def test_build_turn_prompt_without_shared_memory
    actor = WritersRoom::Actor.new(
      character_info: @character_info,
      scene_info: @scene_info,
      bus: @bus,
      config: @config
    )

    message = OpenStruct.new(from: "bob", content: "Hello")
    prompt = actor.send(:build_turn_prompt, message)

    assert_includes prompt, "[bob]: Hello"
    refute_includes prompt, "[Recent dialog]"
  end

  def test_build_turn_prompt_limits_recent_dialog
    history = Array.new(20) { |i| { from: "actor#{i}", content: "Line #{i}", emotion: nil } }
    actor = build_actor
    @memory.set(:dialog_history, history)

    message = OpenStruct.new(from: "bob", content: "Latest")
    prompt = actor.send(:build_turn_prompt, message)

    refute_includes prompt, "actor0: Line 0"
    assert_includes prompt, "actor19: Line 19"
    assert_includes prompt, "actor10: Line 10"
  end

  def test_build_turn_prompt_empty_dialog_history
    actor = build_actor
    @memory.set(:dialog_history, [])

    message = OpenStruct.new(from: "bob", content: "First message")
    prompt = actor.send(:build_turn_prompt, message)

    assert_includes prompt, "[bob]: First message"
    refute_includes prompt, "[Recent dialog]"
  end

  def test_build_tools_returns_five_tools
    actor = build_actor
    tools = actor.send(:build_tools)

    assert_equal 5, tools.length
    assert_kind_of WritersRoom::SpeakTool, tools[0]
    assert_kind_of WritersRoom::ReadMemoryTool, tools[1]
    assert_kind_of WritersRoom::WriteMemoryTool, tools[2]
    assert_kind_of WritersRoom::ListMemoryTool, tools[3]
    assert_kind_of WritersRoom::MarkSceneCompleteTool, tools[4]
  end

  def test_fetch_field_symbol_key
    actor = build_actor
    assert_equal "Alice", actor.send(:fetch_field, :name)
  end

  def test_fetch_field_string_key
    info = { "name" => "Bob" }
    actor = WritersRoom::Actor.new(
      character_info: info,
      scene_info: @scene_info,
      bus: @bus,
      config: @config
    )
    assert_equal "Bob", actor.send(:fetch_field, :name)
  end

  def test_fetch_field_default
    actor = build_actor
    assert_equal "fallback", actor.send(:fetch_field, :nonexistent, "fallback")
  end

  def test_fetch_field_from_alternate_hash
    actor = build_actor
    result = actor.send(:fetch_field, :scene_name, "", from: @scene_info)
    assert_equal "Coffee Shop", result
  end

  def test_recent_dialog_limit_constant
    assert_equal 10, WritersRoom::Actor::RECENT_DIALOG_LIMIT
  end

  def test_extract_objectives_joins_array
    actor = build_actor
    result = actor.send(:extract_objectives)
    assert_equal "Have a conversation about the future", result
  end

  def test_extract_objectives_multiple_items
    @scene_info[:objectives] = ["Goal one", "Goal two", "Goal three"]
    actor = build_actor
    result = actor.send(:extract_objectives)
    assert_equal "Goal one; Goal two; Goal three", result
  end

  def test_extract_objectives_string_passthrough
    @scene_info[:objectives] = "Just one goal"
    actor = build_actor
    result = actor.send(:extract_objectives)
    assert_equal "Just one goal", result
  end

  def test_extract_objectives_empty
    @scene_info[:objectives] = ""
    actor = build_actor
    result = actor.send(:extract_objectives)
    assert_equal "", result
  end

  def test_actor_is_robot_lab_robot
    actor = build_actor
    assert_kind_of RobotLab::Robot, actor
  end

  def test_format_relationships_with_string_keys
    info = { name: "Bob", "relationships" => { "Alice" => "friend" } }
    actor = WritersRoom::Actor.new(
      character_info: info,
      scene_info: @scene_info,
      bus: @bus,
      config: @config
    )
    assert_includes actor.send(:format_relationships), "- Alice: friend"
  end

  private

  def build_actor
    WritersRoom::Actor.new(
      character_info: @character_info,
      scene_info: @scene_info,
      bus: @bus,
      shared_memory: @memory,
      display: @display,
      config: @config
    )
  end
end
