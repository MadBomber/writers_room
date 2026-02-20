# Quick Reference

## CLI Commands

### Project Setup

```bash
wr init PROJECT_NAME [--medium MEDIUM] [--provider PROVIDER] [--model MODEL] [--concept CONCEPT]
wr status                 # project state and next steps
wr config                 # resolved LLM configuration
wr version                # gem version
wr tree                   # full command tree
wr                        # start interactive chat (default command)
wr help [COMMAND] [--verbose]
```

### Writer Tools

LLM-assisted content development. Add `--chat` for interactive mode.

```bash
wr write develop-concept [--chat]
wr write develop-character NAME [--personality PERSONALITY] [--background BACKGROUND] [--chat]
wr write create-arc NAME --description DESCRIPTION [--chat]
wr write breakdown-scenes ARC_NAME [--num-scenes NUM_SCENES] [--chat]
wr write list-arcs
```

### Element Management

Universal CRUD for any element type. Each supports `create`, `list`, `show`, `version`, and `status`.

```bash
wr character create NAME [--personality P] [--speaking-style S] [--background B]
wr character list

wr scene create NAME [--description D] [--characters CHAR1 CHAR2 ...]
wr scene list

wr chapter create NAME [--body BODY] [--status STATUS]
wr chapter list
wr chapter show SLUG
wr chapter version SLUG           # create versioned snapshot
wr chapter status SLUG NEW_STATUS # update status
```

Also available: `arc`, `location`, `setting`, `relationship`, `theme` -- all with the same subcommands.

### Story Bible

```bash
wr bible regenerate     # rebuild from project files
wr bible show           # display all indexed elements
wr bible search TERM    # find by name, slug, or substring
```

### Directing and Production

```bash
wr direct SCENE_FILE [--characters DIR] [--output FILE] [--max-lines N]
wr produce [SCENE_FILES...] [--max-lines N] [--output DIR] [--chat]
wr report               # summarize all transcripts
```

### Export

```bash
wr export manuscript [--output FILE]    # formatted manuscript (adapts to medium)
wr export bible [--output FILE]         # story bible as markdown
wr export references [--output FILE]    # cross-reference graph
```

## Recommended Workflow

```
 1. wr init my_project --medium novella --concept "your concept"
 2. cd my_project
 3. wr write develop-concept --chat
 4. wr write develop-character <name> --chat
 5. wr character create <name> --personality "..." --speaking-style "..."
 6. wr write create-arc <name> --description "..."
 7. wr write breakdown-scenes <arc_name>
 8. wr chapter create <name> --body "..."
 9. wr scene create <name> --description "..." --characters Char1 Char2
10. wr direct scenes/<scene>.md
11. wr produce
12. wr report
13. wr export manuscript
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

Structure varies by medium. A novella project:

```
my_novella/
  config.yml          # Provider and model settings (only YAML file)
  project.md          # Metadata: name, concept, medium
  story_bible.yml     # Auto-generated element index
  characters/         # Character files (.md with front matter)
  relationships/
  arcs/
  settings/
  locations/
  backstory/
  chapters/           # Chapter files (.md with front matter)
  drafts/
  transcripts/
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

- Use `--medium` with `wr init` to skip the interactive medium picker
- Use `--max-lines 20` for quick test runs
- Use `--chat` on any write command for interactive LLM conversation
- Enable `DEBUG_ME=1` if scenes aren't producing output
- Press Ctrl+C to stop a scene and save the transcript
- Run `wr bible regenerate` after adding elements to keep the index current
- Run `wr status` to see project state and suggested next steps
