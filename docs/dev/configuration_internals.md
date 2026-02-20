# Configuration Internals

## Config Class

`WritersRoom::Config` provides the resolved configuration for the current project. Settings cascade:

1. Built-in defaults (in `lib/writers_room/config/defaults.yml`)
2. Per-project `config.yml`
3. Environment variables (prefixed with `WRITERS_ROOM_`)

Access via `WritersRoom.config`:

```ruby
WritersRoom.config.provider    # => "ollama"
WritersRoom.config.model_name  # => "gpt-oss:20b"
WritersRoom.config.ollama_url  # => "http://localhost:11434"
```

The config is a singleton cached on `WritersRoom`. Use `WritersRoom.reset_config!` to clear the cache.

## LLMSetup Module

`WritersRoom::LLMSetup` centralizes LLM provider configuration. It eliminates duplication that previously existed between Writer and ChatSession.

### configure_ruby_llm

Sets up the RubyLLM gem for the configured provider:

```ruby
WritersRoom::LLMSetup.configure_ruby_llm(WritersRoom.config)
```

This configures API keys, base URLs, and provider-specific settings based on the config's `provider` field.

### build_run_config

Returns a `RobotLab::RunConfig` that can be passed to robots:

```ruby
run_config = WritersRoom::LLMSetup.build_run_config(WritersRoom.config)
# => RobotLab::RunConfig with model, temperature, etc.
```

The RunConfig is used by Actor (via Room), Writer, and ChatSession to ensure consistent LLM settings across the application.

## Environment Variable Mapping

| Variable | Config Method | Default |
|----------|--------------|---------|
| `WRITERS_ROOM_PROVIDER` | `provider` | `ollama` |
| `WRITERS_ROOM_MODEL_NAME` | `model_name` | `gpt-oss:20b` |
| `WRITERS_ROOM_OLLAMA_URL` | `ollama_url` | `http://localhost:11434` |
| `WRITERS_ROOM_SCENE_MAX_LINES` | `scene_max_lines` | `50` |
| `WRITERS_ROOM_SCENE_TIMEOUT` | `scene_timeout` | `300` |

Provider-specific API keys (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`) are read directly by RubyLLM.

## Template Path

The `ROBOT_LAB_TEMPLATE_PATH` environment variable is set automatically in `lib/writers_room.rb` to point at the gem's `prompts/` directory. This allows RobotLab's prompt_manager to find WritersRoom's templates.

```ruby
ENV["ROBOT_LAB_TEMPLATE_PATH"] ||= File.expand_path("writers_room/prompts", __dir__)
```

Project-level `prompts/` directories override gem defaults by placing files with the same names.

## Reset

For testing, reset the cached config:

```ruby
WritersRoom.reset_config!
```

For the medium registry:

```ruby
WritersRoom::MediumRegistry.reset!
```
