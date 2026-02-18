# frozen_string_literal: true

require "test_helper"

class ConfigTest < Minitest::Test
  def setup
    WritersRoom.reset_config!
  end

  def teardown
    WritersRoom.reset_config!
  end

  def test_default_provider
    config = WR::Config.new
    assert_equal "ollama", config.provider
  end

  def test_default_model_name
    config = WR::Config.new
    assert_equal "gpt-oss:20b", config.model_name
  end

  def test_default_scene_max_lines
    config = WR::Config.new
    assert_equal 50, config.scene.max_lines
  end

  def test_default_scene_timeout
    config = WR::Config.new
    assert_equal 300, config.scene.timeout
  end

  def test_singleton_accessor
    config = WritersRoom.config
    assert_instance_of WR::Config, config
    assert_same config, WritersRoom.config
  end

  def test_reset_config
    first = WritersRoom.config
    WritersRoom.reset_config!
    second = WritersRoom.config
    refute_same first, second
  end

  def test_env_var_override
    ENV["WRITERS_ROOM_PROVIDER"] = "anthropic"
    config = WR::Config.new
    assert_equal "anthropic", config.provider
  ensure
    ENV.delete("WRITERS_ROOM_PROVIDER")
  end

  def test_env_var_model_override
    ENV["WRITERS_ROOM_MODEL_NAME"] = "claude-sonnet-4-20250514"
    config = WR::Config.new
    assert_equal "claude-sonnet-4-20250514", config.model_name
  ensure
    ENV.delete("WRITERS_ROOM_MODEL_NAME")
  end
end
