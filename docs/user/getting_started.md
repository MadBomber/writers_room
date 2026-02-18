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
wr init my_show --concept "A comedy about two rival chefs"
cd my_show
```

This creates:

```
my_show/
  config.yml          # LLM provider and model settings
  project.md          # Project metadata and concept
  characters/         # Character markdown files
  scenes/             # Scene markdown files
  transcripts/        # Generated dialog transcripts
  arcs/               # Story arc outlines
```

All project files except `config.yml` are markdown with YAML front matter.

## Develop Your Story

Use the writer tools to flesh out your project with LLM assistance:

```bash
# Expand the concept into a fuller description
wr write develop-concept

# Develop a character profile
wr write develop-character "Chef Marco" --personality "fiery Italian perfectionist"

# Create a story arc
wr write create-arc "Act 1" --description "The rival chefs are forced to share a kitchen"

# Break down the arc into scenes
wr write breakdown-scenes "Act 1" --num-scenes 5
```

All writer commands support `--chat` for interactive conversation with the LLM.

## Create Characters and Scenes

```bash
# Create character files
wr character create "Chef Marco" --personality "perfectionist" --speaking-style "passionate"
wr character create "Chef Luna" --personality "innovative" --speaking-style "calm and precise"

# Create a scene
wr scene create "Kitchen Clash" --description "First day sharing the kitchen" --characters Marco Luna
```

## Direct a Scene

```bash
wr direct scenes/kitchen_clash.md
```

Each character maintains its own personality and voice throughout the dialog. The scene ends when the line limit is reached or the timeout expires.

## Run a Full Production

```bash
# Produce all scenes in the project
wr produce

# Or produce specific scenes
wr produce scenes/kitchen_clash.md scenes/taste_test.md

# Interactive chat mode for production planning
wr produce --chat
```

## Generate a Report

```bash
wr report
```

Summarizes all transcripts with line counts per character and scene statistics.

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

- Run commands from inside a project directory (one containing `config.yml` or `project.md`)
- Or create a new project with `wr init`
