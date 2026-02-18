# Quick Reference

## CLI Commands

### Project Setup

```bash
wr init PROJECT_NAME [--provider PROVIDER] [--model MODEL] [--concept CONCEPT]
wr config
wr version
wr help [COMMAND] [--verbose]
```

### Writer Tools

```bash
wr write develop-concept [--chat]
wr write develop-character NAME [--personality PERSONALITY] [--background BACKGROUND] [--chat]
wr write create-arc NAME --description DESCRIPTION [--chat]
wr write breakdown-scenes ARC_NAME [--num-scenes NUM_SCENES] [--chat]
wr write list-arcs
```

### Character Management

```bash
wr character create NAME [--personality PERSONALITY] [--speaking-style STYLE] [--background BACKGROUND]
wr character list
```

### Scene Management

```bash
wr scene create NAME [--description DESCRIPTION] [--characters CHAR1 CHAR2 ...]
wr scene list
```

### Directing and Production

```bash
wr direct SCENE_FILE [--characters CHARACTER_DIR] [--output OUTPUT_FILE] [--max-lines MAX_LINES]
wr produce [SCENE_FILES...] [--max-lines MAX_LINES] [--output OUTPUT_DIR] [--chat]
wr report
```

## Recommended Workflow

```
 1. wr init my_project --concept "your concept"
 2. cd my_project
 3. wr write develop-concept --chat
 4. wr write develop-character <name> --chat
 5. wr write create-arc <name> --description "description"
 6. wr write breakdown-scenes <arc_name>
 7. wr character create <name> --personality "personality" --speaking-style "style"
 8. wr scene create <name> --description "description" --characters Char1 Char2
 9. wr direct scenes/<scene>.md
10. wr produce
11. wr report
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WRITERS_ROOM_PROVIDER` | `ollama` | LLM provider |
| `WRITERS_ROOM_MODEL_NAME` | `gpt-oss:20b` | Model name |
| `WRITERS_ROOM_OLLAMA_URL` | `http://localhost:11434` | Ollama server URL |
| `WRITERS_ROOM_SCENE_MAX_LINES` | `50` | Max lines per scene |
| `WRITERS_ROOM_SCENE_TIMEOUT` | `300` | Scene timeout (seconds) |
| `OPENAI_API_KEY` | -- | Required for OpenAI provider |
| `ANTHROPIC_API_KEY` | -- | Required for Anthropic provider |
| `MAX_LINES` | `50` | Also accepted directly |
| `DEBUG_ME` | -- | Set to `1` for debug output |

## Project Directory Structure

```
my_project/
  config.yml        # Provider and model settings (only YAML file)
  project.md        # Metadata, concept, story arcs
  characters/       # Character files (.md with front matter)
  scenes/           # Scene files (.md with front matter)
  transcripts/      # Generated transcripts (.md with front matter)
  arcs/             # Arc outlines and breakdowns (.md with front matter)
```

## Provider Quick Switch

```bash
# Ollama (default, no API key needed)
ollama serve && ollama pull gpt-oss:20b

# OpenAI
export WRITERS_ROOM_PROVIDER=openai
export WRITERS_ROOM_MODEL_NAME=gpt-4
export OPENAI_API_KEY=sk-...

# Anthropic
export WRITERS_ROOM_PROVIDER=anthropic
export WRITERS_ROOM_MODEL_NAME=claude-sonnet-4-20250514
export ANTHROPIC_API_KEY=sk-ant-...
```

## Tips

- Use `--max-lines 20` for quick test runs
- Use `--chat` on any write command for interactive LLM conversation
- Enable `DEBUG_ME=1` if scenes aren't producing output
- Press Ctrl+C to stop a scene and save the transcript
