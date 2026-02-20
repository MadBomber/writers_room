> This project is under active development.
> Do not trust any of the documentation.

# WritersRoom

A CLI tool for creative writing. Develop characters, plan story arcs, break down scenes, and generate multi-character dialog -- all from the command line with LLM assistance.

The workflow follows a writers' room model: write material, direct scenes, produce the show.

## Install

```bash
gem install writers_room
```

Requires an LLM provider. [Ollama](https://ollama.ai) works out of the box with no API key.

## Quick Start

```bash
wr init my_novella --medium novella --concept "A detective retires, then a letter arrives"
cd my_novella
```

This creates a project directory with `config.yml`, `project.md`, `story_bible.yml`, and scaffolded subdirectories for the chosen medium.

## Media Types

Each medium scaffolds different directories and workflows:

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

## Commands

### Project

```bash
wr init PROJECT_NAME      # create a new project
wr status                 # show project state and next steps
wr config                 # show current LLM configuration
wr                        # start interactive chat session (default)
```

### Writer Tools

LLM-assisted content development. Add `--chat` for interactive mode.

```bash
wr write develop-concept                    # expand the project concept
wr write develop-character "Alice" -p shy   # generate a character profile
wr write create-arc "Act 1" -d "Setup"      # outline a story arc
wr write breakdown-scenes "Act 1"           # break an arc into scenes
wr write list-arcs                          # list all arcs in metadata
```

### Elements

Universal CRUD for any element type. Each supports `create`, `list`, `show`, `version`, and `status`.

```bash
wr character create "Alice Morgan" -p curious -s formal -b "Retired detective"
wr character list

wr chapter create "The Letter" --body "Alice finds a mysterious letter."
wr chapter show the_letter
wr chapter version the_letter           # create a versioned snapshot
wr chapter status the_letter revision   # update status

wr scene create "Opening" -d "A quiet morning" -c alice_morgan bob_crane
wr scene list
```

Also available: `arc`, `location`, `setting`, `relationship`, `theme`.

### Story Bible

An auto-generated index mapping slugs and aliases to files.

```bash
wr bible regenerate     # rebuild from project files
wr bible show           # display all indexed elements
wr bible search "Alice" # find by name, slug, or substring
```

### Production

For dialog-oriented media. Directs scenes with LLM-powered actors.

```bash
wr direct scenes/opening.md -l 50   # direct a single scene
wr produce                           # run all scenes
wr produce --chat                    # plan production interactively first
wr report                            # summarize all transcripts
```

### Export

```bash
wr export manuscript    # formatted manuscript (adapts to medium)
wr export bible         # story bible as markdown
wr export references    # cross-reference graph
```

### Help

```bash
wr help                 # list all commands
wr help write           # help for a subcommand
wr help --verbose       # comprehensive reference
wr tree                 # print full command tree
```

## Project Structure

All project files are markdown with YAML front matter. The only exception is `config.yml`.

```
my_novella/
  config.yml          # LLM provider and model settings
  project.md          # project metadata (name, concept, medium)
  story_bible.yml     # auto-generated element index
  characters/
    alice_morgan.md
  chapters/
    the_letter.md
    the_letter_v1.md  # versioned snapshot
  arcs/
  settings/
  locations/
  relationships/
  backstory/
  drafts/
  transcripts/
```

## Configuration

Default provider is Ollama with the `gpt-oss` model. Override via `config.yml` or environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `RUBY_LLM_PROVIDER` | `ollama` | LLM provider |
| `RUBY_LLM_MODEL` | `gpt-oss` | Model name |
| `OLLAMA_URL` | `http://localhost:11434` | Ollama server URL |

## License

MIT
