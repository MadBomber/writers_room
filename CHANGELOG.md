# Writer's Room - Changelog

## [0.0.3] - 2026-02-20

### Bug Fixes

- **Project scaffolding** — `wr init` now creates `story_bible.yml` in new projects; `ensure_project_structure` calls `scaffold!` instead of `create_directories`
- **Scene/character creation** — `create_scene` and `create_character` now call `FileUtils.mkdir_p` so they work even when the target directory is not in the medium's scaffolded dirs
- **Writer chat mode** — All four `chat_about_*` methods called `session.start` which did not exist on `ChatSession`; replaced with `ChatTui.new(session).run`
- **Story bible search** — `StoryBible#resolve` only did exact matching; added substring fallback so `wr bible search "Alice"` finds "Alice Morgan"
- **Element count inflation** — `ProjectState#element_counts` counted version files (`_v1.md`, `_v2.md`) as separate elements; now excludes `_v\d+.md` files
- **Nil body crash** — `FrontMatter.dump` raised `NoMethodError` when `body` was `nil`; added `body.to_s` guard
- **Missing require** — `CrossReference` used `Set` without `require "set"`; added the require for backward compatibility

### Improvements

- **CLI tree display** — `wr tree` now shows clean names:
  - Root displays `wr` instead of `writers_room:c_l_i`
  - Dynamic element subcommands show their type name instead of anonymous class hex addresses
  - Named subcommands show short names instead of full Ruby constant paths
- **Zeitwerk configuration** — Added `"cli" => "CLI"` inflection and `loader.ignore` for the `cli/` directory to prevent conflicts with manual autoloading

## [unreleased]

## [0.0.2]  - unreleased

- Ollama Configuration Update

### Changed

#### Default LLM Provider Configuration
- **Default Provider**: Changed to Ollama (was: environment-dependent)
- **Default Model**: Set to `gpt-oss`
- **Default URL**: `http://localhost:11434`
- **Timeout**: Set to 120 seconds (2 minutes)

#### Files Modified

**actor.rb** - `setup_llm` method:
- Added explicit Ollama configuration as default
- Added environment variable support for customization:
  - `RUBY_LLM_PROVIDER` - Override provider (default: ollama)
  - `RUBY_LLM_MODEL` - Override model (default: gpt-oss)
  - `OLLAMA_URL` - Override Ollama server URL
- Added timeout configuration
- Enhanced debug output to show provider, model, and base_url

**run_scene_example.sh**:
- Added Ollama service check before running scenes
- Added gpt-oss model availability check
- Provides helpful error messages if Ollama not running
- Suggests alternative providers if Ollama unavailable
- Respects `RUBY_LLM_PROVIDER` environment variable

**README.md**:
- Updated "Configure LLM Provider" section
- Changed from multiple providers to Ollama-first approach
- Added environment variable override instructions
- Added Ollama verification steps
- Added link to CONFIGURATION.md

**QUICKSTART.md**:
- Updated Step 2 to focus on Ollama setup
- Changed from API keys to Ollama serve instructions
- Added model pull instructions
- Simplified getting started flow

### Added

**CONFIGURATION.md** - New comprehensive configuration guide:
- Default configuration reference
- Environment variables table
- Configuration examples for all providers
- Model selection guide
- Performance tuning recommendations
- Troubleshooting configuration issues
- Advanced configuration options

### Environment Variables

New environment variables supported:

| Variable | Default | Purpose |
|----------|---------|---------|
| `RUBY_LLM_PROVIDER` | `ollama` | LLM provider selection |
| `RUBY_LLM_MODEL` | `gpt-oss` | Model name |
| `OLLAMA_URL` | `http://localhost:11434` | Ollama server URL |
| `MAX_LINES` | `50` | Maximum dialog lines per scene |
| `DEBUG_ME` | (unset) | Debug mode toggle |

Existing variables still supported:
- `OPENAI_API_KEY` - For OpenAI provider
- `ANTHROPIC_API_KEY` - For Anthropic provider

### Migration Guide

#### Before (Generic Configuration)

```bash
# User had to configure provider
export OPENAI_API_KEY="sk-..."
./director.rb -s scenes/scene_01_gym_wars.yml
```

#### After (Ollama Default)

```bash
# Just start Ollama and run
ollama serve
ollama pull gpt-oss
./run_scene_example.sh
```

#### Switching Providers (Still Easy)

**Use OpenAI:**
```bash
export RUBY_LLM_PROVIDER="openai"
export OPENAI_API_KEY="sk-..."
./director.rb -s scenes/scene_01_gym_wars.yml
```

**Use Different Ollama Model:**
```bash
export RUBY_LLM_MODEL="llama2"
./director.rb -s scenes/scene_01_gym_wars.yml
```

### Benefits

1. **Out-of-the-box Experience**: Works immediately with local Ollama
2. **No API Keys Required**: For default configuration
3. **Cost-Free**: Using local models
4. **Privacy**: Data stays on your machine
5. **Flexibility**: Easy to switch providers when needed
6. **Development-Friendly**: Fast iteration with local models

### Backwards Compatibility

✅ All existing environment variable configurations still work
✅ Existing provider integrations unchanged (OpenAI, Anthropic, etc.)
✅ Can still use cloud providers by setting `RUBY_LLM_PROVIDER`
✅ No breaking changes to Actor or Director APIs

### Requirements

**New Requirement (for default config):**
- Ollama must be installed and running
- gpt-oss model must be pulled

**Alternative:**
- Set `RUBY_LLM_PROVIDER` to use OpenAI, Anthropic, or others

### Verification

Check your configuration is working:

```bash
# 1. Verify Redis
redis-cli ping

# 2. Verify Ollama
curl http://localhost:11434
ollama list | grep gpt-oss

# 3. Run test scene
./run_scene_example.sh

# 4. Check logs for configuration
DEBUG_ME=1 ./actor.rb -c characters/marcus.yml -s scenes/scene_01_gym_wars.yml
```

Expected debug output:
```
DEBUG: LLM setup complete for Marcus
  provider: "ollama"
  model: "gpt-oss"
  base_url: "http://localhost:11434"
```

### Documentation Updates

- ✅ README.md - Updated setup section
- ✅ QUICKSTART.md - Updated to Ollama-first approach
- ✅ CONFIGURATION.md - Added comprehensive configuration guide
- ✅ run_scene_example.sh - Added Ollama checks
- ✅ actor.rb - Added inline documentation

### Future Enhancements

Potential future additions:
- [ ] Auto-detect available Ollama models
- [ ] Fallback provider if Ollama unavailable
- [ ] Configuration file support (.env auto-loading)
- [ ] Per-character model selection
- [ ] Model performance benchmarking
- [ ] Automatic model downloading

---

## Previous Versions

### [Initial Release]

- Created Actor class with RubyLLM integration
- Created Director orchestration system
- Implemented SmartMessage Redis communication
- Added 6 character definitions
- Added 4 scene definitions
- Created comprehensive documentation
