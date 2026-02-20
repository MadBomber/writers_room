# Project Structure

## Project Layout

Each WritersRoom project has a base structure plus medium-specific directories:

```
my_novella/
  config.yml                    # LLM provider and model settings (only YAML file)
  project.md                    # Project metadata: name, concept, medium
  story_bible.yml               # Auto-generated element index
  characters/                   # Character files
    alice_morgan.md
  chapters/                     # Chapter files (novella medium)
    the_letter.md
    the_letter_v1.md            # Versioned snapshot
  arcs/                         # Story arc outlines
  settings/
  locations/
  relationships/
  backstory/
  drafts/
  transcripts/
```

The exact set of subdirectories depends on the medium type chosen during `wr init`. See [Getting Started](getting_started.md#available-media-types) for the full table.

Create a new project with:

```bash
wr init my_novella --medium novella --concept "A detective retires, then a letter arrives"
```

## File Format

Every file in a WritersRoom project (except `config.yml` and `story_bible.yml`) uses markdown with YAML front matter. Structured data goes in the front matter, prose goes in the body.

## Character File Format

```markdown
---
name: Alice Morgan
element_type: characters
status: draft
personality: curious
speaking_style: formal
background: Retired detective
---

## Personality

Retired detective with a sharp analytical mind. Intensely curious,
with a formal speaking style that softens around close friends.

## Voice Pattern

Precise and measured. Uses law-enforcement terminology naturally.
Asks pointed questions even in casual conversation.

## Current Arc

Learning to let go of old cases. Drawn back in by a letter
that reopens questions she thought were settled.
```

### Front Matter Fields

| Field | Description |
|-------|-------------|
| `name` | Character name (matches the name used in scene files) |
| `element_type` | Always `characters` for character files |
| `status` | Workflow status (draft, revision, final, etc.) |
| `personality` | Personality traits |
| `speaking_style` | How the character speaks |
| `background` | Brief backstory |

## Element File Format

All element types (chapters, arcs, locations, settings, relationships, themes) follow the same pattern:

```markdown
---
name: The Letter
element_type: chapters
status: draft
---

Alice finds a mysterious letter on her doorstep. The handwriting
is familiar but she can't place it.
```

### Common Front Matter Fields

| Field | Description |
|-------|-------------|
| `name` | Display name for the element |
| `element_type` | The element's type (chapters, arcs, locations, etc.) |
| `status` | Workflow status |
| `aliases` | Alternative names for story bible lookups |
| `version` | Version number (on versioned snapshots) |
| `based_on` | Source file for a version snapshot |

## Scene File Format

```markdown
---
name: Opening
description: A quiet morning
characters:
  - alice_morgan
element_type: scenes
status: draft
---

## Context

A quiet autumn morning. Alice sits on her porch with coffee,
watching leaves drift across the yard.

## Scene Objectives

**Alice:** Establish her retired life and hint at restlessness.

## Beat Structure

1. **Morning routine** -- Alice reads the paper, checks the mail.
2. **The letter** -- She finds an unmarked envelope.
```

## Versioning

Any element can be versioned. Versions are stored as `slug_v1.md`, `slug_v2.md`, etc. in the same directory:

```bash
wr chapter version the_letter    # creates the_letter_v1.md
wr chapter version the_letter    # creates the_letter_v2.md
```

Version files are excluded from element listings and counts. They serve as snapshots you can refer back to.

## Story Bible

The `story_bible.yml` file is an auto-generated index mapping element slugs and aliases to their files. It is rebuilt from project files:

```bash
wr bible regenerate     # rebuild from all project files
wr bible show           # display indexed elements
wr bible search "Alice" # find by name, slug, or substring
```

The story bible supports exact matching on slug, name, and aliases, with a substring fallback for partial matches.

## Prompt Templates

WritersRoom uses [RobotLab](https://github.com/madbomber/robot_lab) templates for its LLM prompts. Templates are markdown files with YAML front matter and ERB interpolation.

Default templates ship with the gem in `lib/writers_room/prompts/`:

| Template | Purpose |
|----------|---------|
| `actor_system.md` | Character identity and scene instructions |
| `actor_dialog.md` | Dialog generation from conversation history |
| `develop_concept.md` | Expand a project concept |
| `develop_character.md` | Build a detailed character profile |
| `create_arc.md` | Create a story arc outline |
| `breakdown_scenes.md` | Break an arc into individual scenes |

To customize prompts for a project, create a `prompts/` directory in your project and add your own versions. Project-level prompts override the gem defaults.

```
my_novella/
  prompts/                        # Optional per-project prompt overrides
    actor_system.md               # Custom character instructions
    develop_concept.md            # Custom concept development style
  config.yml
  project.md
  story_bible.yml
  characters/
  chapters/
  ...
```

Templates use ERB for variable interpolation:

```markdown
---
description: System prompt for character actors
parameters:
  character_name: null
  personality: null
---
You are <%= character_name %>.

## Personality

<%= personality %>
```

See the default templates in the gem for the full set of available variables.

## Character Directory Auto-Detection

When you run `wr direct scenes/scene_01.md`, WritersRoom locates characters automatically:

1. If `--characters` flag is provided, use that path
2. If the scene is inside a `scenes/` directory, look for a sibling `characters/` directory
3. Fall back to `characters/` in the current directory

This means you can run scenes from inside a project directory without specifying the character path:

```bash
cd my_novella
wr direct scenes/opening.md
```
