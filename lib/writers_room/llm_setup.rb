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

      register_local_model(config.model_name, provider)
    end

    # Pre-register a model in the RubyLLM registry for local providers.
    #
    # RobotLab's RunConfig doesn't carry a provider field, so when
    # RubyLLM::Chat resolves the model it searches the static registry
    # without knowing which provider to use. Local providers (Ollama,
    # GPUStack) aren't in the static registry, causing "Unknown model"
    # errors. This method registers the model so resolution succeeds.
    #
    # @param model_name [String] the model identifier
    # @param provider [String] the provider name
    def register_local_model(model_name, provider)
      provider_sym = provider.to_sym
      provider_class = RubyLLM::Provider.providers[provider_sym]
      return unless provider_class

      provider_instance = provider_class.new(RubyLLM.config)
      return unless provider_instance.local?

      # Skip if already registered
      return if RubyLLM::Models.all.any? { |m| m.id == model_name && m.provider == provider }

      default_info = RubyLLM::Model::Info.default(model_name, provider_instance.slug)
      RubyLLM::Models.instance.all << default_info
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
