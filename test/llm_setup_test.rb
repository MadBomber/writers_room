# frozen_string_literal: true

require "test_helper"

class LLMSetupTest < Minitest::Test
  def test_build_run_config_returns_run_config
    config = WritersRoom.config
    run_config = WritersRoom::LLMSetup.build_run_config(config)

    assert_instance_of RobotLab::RunConfig, run_config
  end

  def test_build_run_config_uses_model_from_config
    config = WritersRoom.config
    run_config = WritersRoom::LLMSetup.build_run_config(config)

    assert_equal config.model_name, run_config.model
  end

  def test_build_run_config_applies_overrides
    config = WritersRoom.config
    run_config = WritersRoom::LLMSetup.build_run_config(config, model: "custom-model")

    assert_equal "custom-model", run_config.model
  end

  def test_configure_ruby_llm_for_ollama
    config = WritersRoom.config
    # Default provider is ollama — should not raise
    WritersRoom::LLMSetup.configure_ruby_llm(config)
  end

  def test_build_run_config_defaults_to_writers_room_config
    # Call without explicit config — should use WritersRoom.config
    run_config = WritersRoom::LLMSetup.build_run_config

    assert_instance_of RobotLab::RunConfig, run_config
    assert_equal WritersRoom.config.model_name, run_config.model
  end
end
