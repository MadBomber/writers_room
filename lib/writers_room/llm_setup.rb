# frozen_string_literal: true

module WritersRoom
  # Shared LLM configuration to eliminate duplication between Writer,
  # ChatSession, and other components that need to configure RubyLLM
  # and build RobotLab RunConfigs.
  module LLMSetup
    module_function

    # Configure RubyLLM for the given provider.
    #
    # @param config [WritersRoom::Config] project configuration
    def configure_ruby_llm(config = WritersRoom.config)
      provider = config.provider

      RubyLLM.configure do |c|
        case provider
        when "ollama"
          c.ollama_api_base = config.ollama_url
        when "openai"
          c.openai_api_key = ENV["OPENAI_API_KEY"]
        when "anthropic"
          c.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
        end
      end
    end

    # Build a RobotLab::RunConfig from WritersRoom config.
    #
    # @param config [WritersRoom::Config] project configuration
    # @param overrides [Hash] additional RunConfig fields
    # @return [RobotLab::RunConfig]
    def build_run_config(config = WritersRoom.config, **overrides)
      configure_ruby_llm(config)

      fields = { model: config.model_name }
      fields.merge!(overrides)

      RobotLab::RunConfig.new(**fields)
    end
  end
end
