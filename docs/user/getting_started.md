# Getting Started

## Installation

```bash
gem install writers_room
```

## Prerequisites

WritersRoom uses [Ollama](https://ollama.ai) by default. Start Ollama and pull the default model:

```bash
ollama serve
ollama pull gpt-oss:20b
```

To use OpenAI or Anthropic instead, see [Configuration](configuration.md).

## Create a Project

```bash
wr init my_novella --medium novella --concept "A detective retires, then a letter arrives"
cd my_novella
```

If you omit `--medium`, an interactive menu lists available media types. Each medium scaffolds directories and workflows suited to that format.

### Available Media Types

| Medium | Directories |
|--------|-------------|
| dialog | characters, scenes, transcripts, arcs |
| documentary | research, timeline, segments, interviews, transcripts, sources |
| novel | characters, relationships, arcs, settings, locations, research, timeline, backstory, chapters, parts, transcripts |
| novella | characters, relationships, arcs, settings, locations, backstory, chapters, drafts, transcripts |
| radio_play | characters, arcs, settings, episodes, scenes, transcripts, sound_design |
| screenplay | characters, arcs, settings, locations, acts, sequences, scenes, transcripts |
| short_story | characters, settings, scenes, drafts, transcripts |
| stage_play | characters, arcs, settings, acts, scenes, transcripts |
| tv_series | characters, arcs, settings, locations, seasons, episodes, scenes, transcripts |

### What Gets Created

```
my_novella/
  config.yml          # LLM provider and model settings
  project.md          # Project metadata (name, concept, medium)
  story_bible.yml     # Auto-generated element index
  characters/         # Character files
  chapters/           # Chapter files
  arcs/               # Story arcs
  ...                 # Other dirs based on medium
```

All project files except `config.yml` are markdown with YAML front matter.

## Develop Your Story

Use the writer tools to flesh out your project with LLM assistance:

```bash
# Expand the concept into a fuller description
wr write develop-concept

# Develop a character profile
wr write develop-character "Alice" --personality "retired detective, sharp but weary"

# Create a story arc
wr write create-arc "Act 1" --description "The letter changes everything"

# Break down the arc into scenes
wr write breakdown-scenes "Act 1" --num-scenes 5
```

All writer commands support `--chat` for interactive conversation with the LLM.

## Create Story Elements

WritersRoom provides universal CRUD commands for all element types. Each supports `create`, `list`, `show`, `version`, and `status`.

```bash
# Characters
wr character create "Alice Morgan" --personality "curious" --speaking-style "formal"
wr character list

# Chapters (novel/novella)
wr chapter create "The Letter" --body "Alice finds a mysterious letter."
wr chapter show the_letter
wr chapter version the_letter           # create a versioned snapshot
wr chapter status the_letter revision   # update status

# Scenes
wr scene create "Opening" --description "A quiet morning" --characters alice_morgan
wr scene list

# Other element types
wr arc create "Main Arc" --body "The central conflict"
wr location create "The Study"
wr setting create "Victorian London"
wr relationship create "Alice and Bob"
wr theme create "Identity"
```

## Story Bible

The story bible is an auto-generated index mapping slugs and aliases to files.

```bash
wr bible regenerate     # rebuild from project files
wr bible show           # display all indexed elements
wr bible search "Alice" # find by name, slug, or substring
```

## Project Status

Check your project's state and get suggested next steps:

```bash
wr status
```

## Interactive Chat

Run bare `wr` (no subcommand) to start a context-aware interactive writing session:

```bash
wr
```

The chat is aware of your project, medium type, and current working directory.

## Direct a Scene

For dialog-oriented media, direct scenes with LLM-powered actors:

```bash
wr direct scenes/opening.md --max-lines 30
```

Each character maintains its own personality and voice throughout the dialog.

## Run a Full Production

```bash
# Produce all scenes in the project
wr produce

# Interactive chat mode for production planning
wr produce --chat
```

## Generate a Report

```bash
wr report
```

Summarizes all transcripts with line counts per character and scene statistics.

## Export

```bash
wr export manuscript    # formatted manuscript (adapts to medium)
wr export bible         # story bible as markdown
wr export references    # cross-reference graph
```

## Customizing Prompts

WritersRoom ships with default LLM prompt templates. To customize how
characters behave or how the writer tools generate content, create a
`prompts/` directory in your project and add your own template overrides.

See [Project Structure](project_structure.md#prompt-templates) for details.

## Troubleshooting

**"No output from scenes"**

- Verify Ollama is running: `curl http://localhost:11434/api/tags`
- Check that the model is available: `ollama list`
- Enable debug output: `DEBUG_ME=1 wr direct scenes/your_scene.md`

**"Scene runs too long"**

- Set a line limit: `wr direct scenes/your_scene.md --max-lines 20`
- Press Ctrl+C to stop and save the transcript

**"Character file not found"**

- Character names in scene files must match character filenames (lowercase)
- Override the character directory with: `wr direct scenes/your_scene.md --characters path/to/characters/`

**"No project found"**

- Run commands from inside a project directory (one containing `project.md`)
- Or create a new project with `wr init`
