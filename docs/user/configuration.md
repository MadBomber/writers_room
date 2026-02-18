# Configuration

## Overview

Settings cascade in this order (later sources override earlier):

1. Built-in defaults
2. Per-project `config.yml` (the only pure YAML file in a project)
3. Environment variables (prefixed with `WRITERS_ROOM_`)

## Default Values

| Setting | Default |
|---------|---------|
| Provider | `ollama` |
| Model | `gpt-oss:20b` |
| Ollama URL | `http://localhost:11434` |
| Max lines per scene | `50` |
| Scene timeout | `300` seconds |

## Per-Project Configuration

Each project has a `config.yml` created by `wr init`:

```yaml
---
provider: ollama
model_name: gpt-oss:20b
```

Override the provider and model at project creation time:

```bash
wr init my_project --provider openai --model gpt-4
```

Or edit `config.yml` directly.

## Environment Variables

All settings can be overridden with environment variables using the `WRITERS_ROOM_` prefix.

| Variable | Default | Description |
|----------|---------|-------------|
| `WRITERS_ROOM_PROVIDER` | `ollama` | LLM provider |
| `WRITERS_ROOM_MODEL_NAME` | `gpt-oss:20b` | Model to use |
| `WRITERS_ROOM_OLLAMA_URL` | `http://localhost:11434` | Ollama server URL |
| `WRITERS_ROOM_SCENE_MAX_LINES` | `50` | Max dialog lines per scene |
| `WRITERS_ROOM_SCENE_TIMEOUT` | `300` | Scene timeout in seconds |
| `MAX_LINES` | `50` | Also accepted directly |
| `DEBUG_ME` | (unset) | Set to `1` for debug output |

### Provider API Keys

| Variable | Required For |
|----------|-------------|
| `OPENAI_API_KEY` | OpenAI models |
| `ANTHROPIC_API_KEY` | Anthropic Claude models |

## Provider Examples

### Ollama (default)

No API key needed. Start Ollama and pull the model:

```bash
ollama serve
ollama pull gpt-oss:20b
```

### OpenAI

```bash
export WRITERS_ROOM_PROVIDER=openai
export WRITERS_ROOM_MODEL_NAME=gpt-4
export OPENAI_API_KEY=sk-your-key-here

wr direct scenes/scene_01.yml
```

Or set it per-project in `config.yml`:

```yaml
---
provider: openai
model_name: gpt-4
```

### Anthropic

```bash
export WRITERS_ROOM_PROVIDER=anthropic
export WRITERS_ROOM_MODEL_NAME=claude-sonnet-4-20250514
export ANTHROPIC_API_KEY=sk-ant-your-key-here

wr direct scenes/scene_01.yml
```

### Remote Ollama Server

```bash
export WRITERS_ROOM_OLLAMA_URL=http://192.168.1.100:11434
export WRITERS_ROOM_MODEL_NAME=mixtral

wr direct scenes/scene_01.yml
```

## Viewing Current Configuration

```bash
wr config
```

Displays the resolved configuration for the current project directory.

## Debug Mode

Enable debug output:

```bash
DEBUG_ME=1 wr direct scenes/scene_01.yml
```
