# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class ConfigTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @config_path = File.join(@temp_dir, "config.yml")
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_default_config_values
    config = WR::Config.new(@config_path)
    assert_equal "ollama", config.provider
    assert_equal "gpt-oss", config.model_name
  end

  def test_create_project_with_defaults
    project_path = File.join(@temp_dir, "test_project")
    config = WR::Config.create_project(project_path)

    assert File.exist?(project_path)
    assert File.exist?(File.join(project_path, "config.yml"))
    assert_equal "ollama", config.provider
    assert_equal "gpt-oss", config.model_name
  end

  def test_create_project_with_custom_options
    project_path = File.join(@temp_dir, "custom_project")
    config = WR::Config.create_project(
      project_path,
      provider: "anthropic",
      model_name: "claude-3-5-sonnet-20241022"
    )

    assert_equal "anthropic", config.provider
    assert_equal "claude-3-5-sonnet-20241022", config.model_name
  end

  def test_load_existing_config
    config_data = {
      "provider" => "openai",
      "model_name" => "gpt-4"
    }
    File.write(@config_path, YAML.dump(config_data))

    config = WR::Config.new(@config_path)
    assert_equal "openai", config.provider
    assert_equal "gpt-4", config.model_name
  end

  def test_save_config
    config = WR::Config.new(@config_path)
    config.set("provider", "anthropic")
    config.set("model_name", "claude-3-opus")
    assert config.save

    # Reload and verify
    new_config = WR::Config.new(@config_path)
    assert_equal "anthropic", new_config.provider
    assert_equal "claude-3-opus", new_config.model_name
  end

  def test_get_and_set_methods
    config = WR::Config.new(@config_path)

    config.set("custom_key", "custom_value")
    assert_equal "custom_value", config.get("custom_key")
    assert_equal "custom_value", config.get(:custom_key)
  end

  def test_provider_and_model_name_methods
    config = WR::Config.new(@config_path)
    config.set("provider", "test_provider")
    config.set("model_name", "test_model")

    assert_equal "test_provider", config.provider
    assert_equal "test_model", config.model_name
  end
end
