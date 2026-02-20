# WritersRoom Production Workflow

This document describes the complete workflow for creating a production with WritersRoom, following the traditional creative process:

**Producer** → **Writer** → **Director** → **Actor**

## Overview

WritersRoom models the collaborative creative process used in film, television, and theater production:

1. **Producer** - Initiates the project with a concept and sets up the infrastructure
2. **Writer** - Develops the concept into detailed characters, story arcs, and scenes
3. **Director** - Orchestrates actors to perform scenes and create dialog
4. **Actor** - AI-powered characters that improvise dialog based on their profiles

## Complete Workflow

### 1. Producer Phase: Project Initialization

The Producer comes up with the project idea and creates the initial structure.

```bash
# Initialize a new project with a concept
wr init my_show -c "A story about two friends navigating life in a small town"

# This creates:
# - config.yml (technical configuration)
# - project.md (project metadata with concept)
# - directories: characters/, scenes/, transcripts/, arcs/
```

**Files Created:**
- `config.yml` - LLM provider and model configuration
- `project.md` - Project name, concept, story arcs (Markdown with YAML front matter)

### 2. Writer Phase: Story Development

The Writer takes the Producer's concept and develops it into a complete story structure.

#### A. Develop the Concept

```bash
cd my_show
wr write develop-concept
```

This uses LLM to expand the brief concept into a fuller description including:
- Core themes and tone
- World/setting details
- Central conflicts
- Character types needed
- Story structure possibilities

**Output:** `concept_development.md`

#### B. Develop Characters

```bash
# Create detailed character profiles
wr write develop-character "Alice" -p "cheerful and optimistic" -b "Grew up in the town"
wr write develop-character "Bob" -p "cynical but kind-hearted"
```

This generates comprehensive character profiles with:
- Detailed personality traits and quirks
- Background and history
- Motivations and fears
- Speaking style and mannerisms
- Potential character arcs

**Output:** `characters/<name>_development.md`

Then create the actual character files from the development notes:

```bash
wr character create Alice -p cheerful -s "friendly and casual"
wr character create Bob -p cynical -s "sarcastic but warm"
```

**Output:** `characters/<name>.md`

#### C. Create Story Arcs

```bash
# Define the major story arcs
wr write create-arc "Act 1: Setup" -d "Introducing the characters and their world"
wr write create-arc "Act 2: Conflict" -d "The central challenge emerges"
wr write create-arc "Act 3: Resolution" -d "Characters face the climax"

# List all arcs
wr write list-arcs
```

**Output:** `arcs/<arc_name>.md` and updates to `project.md`

#### D. Break Down Scenes

```bash
# Generate scene suggestions from an arc
wr write breakdown-scenes "Act 1: Setup" -n 5
```

This creates specific scene suggestions with:
- Scene names
- Locations
- Characters involved
- What happens
- Dramatic purpose

**Output:** `arcs/<arc_name>_breakdown.md`

Now create the actual scene files:

```bash
wr scene create "Coffee Shop Meeting" -d "Alice and Bob meet for coffee" -c Alice Bob
wr scene create "The Discovery" -d "They find something unexpected" -c Alice Bob

# List all scenes
wr scene list
```

**Output:** `scenes/<scene_name>.md`

### 3. Director Phase: Scene Production

The Director takes the scenes created by the Writer and directs the actors to perform them.

```bash
# Direct a single scene
wr direct scenes/coffee_shop_meeting.md -l 30 -o transcripts/coffee_shop.txt

# The Director:
# - Loads the scene file (Markdown with front matter)
# - Creates a Room with a bus, shared memory, and display
# - Loads Actor robots for each character (template + tools)
# - Actors communicate via the bus and shared memory
# - Saves the transcript
# - Shows statistics
```

**How it works:**
- The Director creates a `Room` that holds a TypedBus message bus and shared memory
- Each character becomes an `Actor` (a RobotLab Robot) with tools for speaking, reading/writing memory, and marking scene completion
- Actors use the `SpeakTool` to broadcast dialog to the `:scene` bus channel
- Other actors receive the message and respond reactively
- The scene ends when `max_lines` is reached or an actor calls `MarkSceneCompleteTool`

### 4. Full Production

Once all scenes are created, the Producer can run the entire production:

```bash
# Run all scenes in the project
wr produce

# Or run specific scenes
wr produce scenes/scene1.md scenes/scene2.md

# Generate a production report
wr report
```

**Output:**
- Multiple transcript files in `transcripts/`
- Aggregate statistics across all scenes
- Lines by character across the entire production

## File Structure

After following the complete workflow, your project will look like this:

```
my_show/
├── config.yml                          # Technical configuration
├── project.md                          # Project metadata, concept, arcs
├── concept_development.md              # Expanded concept from Writer
├── characters/
│   ├── alice.md                        # Character definition (front matter)
│   ├── alice_development.md            # Detailed character profile
│   ├── bob.md
│   └── bob_development.md
├── arcs/
│   ├── act_1_setup.md                  # Arc outline
│   ├── act_1_setup_breakdown.md        # Scene breakdown
│   ├── act_2_conflict.md
│   └── act_3_resolution.md
├── scenes/
│   ├── coffee_shop_meeting.md          # Scene definition (front matter)
│   ├── the_discovery.md
│   └── ...
└── transcripts/
    ├── coffee_shop_meeting.txt         # Generated dialog
    ├── the_discovery.txt
    └── ...
```

## Example Complete Workflow

```bash
# 1. PRODUCER: Initialize project
wr init detective_story -c "A detective investigates a series of mysterious disappearances"

cd detective_story

# 2. WRITER: Develop the story
wr write develop-concept
wr write develop-character "Detective Sarah" -p "sharp and intuitive"
wr write develop-character "Officer Mike" -p "by-the-book but loyal"
wr write create-arc "Investigation Begins" -d "The first disappearance is reported"
wr write breakdown-scenes "Investigation Begins" -n 3

# 3. WRITER/PRODUCER: Create assets
wr character create "Detective Sarah" -p sharp -s "direct and questioning"
wr character create "Officer Mike" -p methodical -s "formal but supportive"
wr scene create "First Report" -d "Sarah learns of the case" -c "Detective Sarah" "Officer Mike"

# 4. DIRECTOR: Shoot the scene
wr direct scenes/first_report.md -l 40

# 5. PRODUCER: Run full production
wr produce

# 6. PRODUCER: Review results
wr report
```

## Key Concepts

### LLM Integration

The Writer uses LLM (via RubyLLM and RobotLab templates) to:
- Expand concepts into fuller descriptions
- Generate detailed character profiles
- Create story arc outlines
- Break arcs into scene suggestions

The Actor uses LLM with RobotLab tools to:
- Generate dialog in character via `SpeakTool`
- Track scene state via shared memory tools
- Signal scene completion via `MarkSceneCompleteTool`

### Bus Messaging and Shared Memory

Actors communicate via a TypedBus message bus:
- Each Room creates a `:scene` channel
- Actors subscribe and broadcast dialog messages through tools
- Shared memory (`RobotLab::Memory`) stores dialog history and scene state
- The `fresh_chat!` pattern resets chat context between turns while shared memory persists

### Configuration

Two configuration sources per project:
1. `config.yml` - Technical settings (LLM provider, model)
2. `project.md` - Creative content (concept, arcs, timeline) as Markdown with YAML front matter

### File Format

All project files (characters, scenes, project metadata) use Markdown with YAML front matter:

```markdown
---
name: Alice
traits:
  personality: cheerful
  speaking_style: casual
  background: A young writer
goals: []
relationships: {}
---

## Background
Alice grew up in a small town...
```

All project files use this format exclusively.

## Interactive Chat Mode

All `wr write` commands and `wr produce` support an interactive `--chat` mode that allows you to consult with the LLM before finalizing content.

### Using Chat Mode

```bash
# Chat about concept development
wr write develop-concept --chat

# Chat about character development
wr write develop-character "Alice" -p cheerful --chat

# Chat about story arc creation
wr write create-arc "Act 1" -d "Setup" --chat

# Chat about scene breakdown
wr write breakdown-scenes "Act 1" --chat

# Chat about production planning
wr produce --chat
```

### Chat Features

When in chat mode:
- Type your questions or ideas naturally
- The LLM responds with context about your project
- Use built-in commands:
  - `help` - Show available commands
  - `context` - Show current context
  - `summary` - Get conversation summary
  - `clear` - Clear conversation history
  - `exit` - End chat session (also: quit, q, bye)

**Chat sessions are saved** to your project directory as markdown files with:
- Full conversation history
- Context information
- Automatic summary of key decisions

## Commands Reference

### Producer Commands
- `wr init <name> [-c concept]` - Initialize project
- `wr config` - Show configuration
- `wr produce [scenes...] [--chat]` - Run production (with optional planning chat)
- `wr report` - Generate statistics

### Writer Commands
- `wr write develop-concept [--chat]` - Expand project concept
- `wr write develop-character <name> [--chat]` - Create character profile
- `wr write create-arc <name> -d <desc> [--chat]` - Create story arc
- `wr write breakdown-scenes <arc> [--chat]` - Generate scene suggestions
- `wr write list-arcs` - List all story arcs

**All writer commands support `--chat` for interactive LLM consultation**

### Character Commands
- `wr character create <name>` - Create character file
- `wr character list` - List all characters

### Scene Commands
- `wr scene create <name>` - Create scene file
- `wr scene list` - List all scenes

### Director Commands
- `wr direct <scene_file>` - Direct a scene
