# frozen_string_literal: true

require "yaml"
require "fileutils"

module WritersRoom
  class Config
    attr_reader :path, :data

    DEFAULT_CONFIG = {
      "provider" => "ollama",
      "model_name" => "gpt-oss:20b",
    }.freeze

    def initialize(path = nil)
      @path = path || default_config_path
      @data = load_config
    end

    # Load configuration from file
    #
    # @return [Hash] configuration data
    def load_config
      return DEFAULT_CONFIG.dup unless File.exist?(path)

      YAML.load_file(path) || DEFAULT_CONFIG.dup
    rescue StandardError => e
      warn "Error loading config from #{path}: #{e.message}"
      DEFAULT_CONFIG.dup
    end

    # Save configuration to file
    #
    # @param config_data [Hash] configuration data to save
    # @return [Boolean] true if successful
    def save(config_data = @data)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, YAML.dump(config_data))
      @data = config_data
      true
    rescue StandardError => e
      warn "Error saving config to #{path}: #{e.message}"
      false
    end

    # Create a new project configuration
    #
    # @param project_path [String] path to project directory
    # @param options [Hash] configuration options
    # @return [WritersRoom::Config] new config instance
    def self.create_project(project_path, options = {})
      FileUtils.mkdir_p(project_path)

      config_path = File.join(project_path, "config.yml")
      config_data = DEFAULT_CONFIG.merge(options.transform_keys(&:to_s))

      config = new(config_path)
      config.save(config_data)
      config
    end

    # Get configuration value
    #
    # @param key [String, Symbol] configuration key
    # @return [Object] configuration value
    def get(key)
      @data[key.to_s]
    end

    # Set configuration value
    #
    # @param key [String, Symbol] configuration key
    # @param value [Object] configuration value
    def set(key, value)
      @data[key.to_s] = value
    end

    # Get provider
    #
    # @return [String] LLM provider name
    def provider
      get("provider")
    end

    # Get model name
    #
    # @return [String] model name
    def model_name
      get("model_name")
    end

    private

    def default_config_path
      File.join(Dir.pwd, "config.yml")
    end
  end
end
