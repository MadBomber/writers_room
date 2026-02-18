# Project Structure

## Project Layout

Each WritersRoom project has this structure:

```
my_project/
  config.yml                    # LLM provider and model settings
  project.md                    # Project metadata, concept, and story arcs
  characters/                   # Character files (markdown with front matter)
    alice.md
    bob.md
  scenes/                       # Scene files (markdown with front matter)
    scene_01_opening.md
    scene_02_conflict.md
  transcripts/                  # Generated dialog transcripts
  arcs/                         # Story arc outlines and breakdowns
```

All project files except `config.yml` are markdown with YAML front matter.

Create a new project with:

```bash
wr init my_project --concept "A story about two rival chefs"
```

This creates `config.yml`, `project.md`, and the four subdirectories.

## File Format

Every file in a WritersRoom project (except `config.yml`) uses markdown with YAML front matter. Structured data goes in the front matter, prose goes in the body.

## Character File Format

```markdown
---
name: Alex
age: 17
sport: Basketball team captain
relationships:
  Tyler: "Soccer captain. Initially rival for gym time."
  Marcus: "Team statistician. Values his insights."
---

## Personality

Basketball team captain. Intensely focused and competitive.
Direct communicator. Strong work ethic.

## Voice Pattern

Direct and concise. Short, punchy sentences when focused.
Uses basketball terms naturally.

## Current Arc

Learning that relationships aren't distractions.
Discovering vulnerability doesn't mean weakness.
```

### Front Matter Fields

| Field | Description |
|-------|-------------|
| `name` | Character name (must match the name used in scene files) |
| `age` | Character age |
| `sport` | Activity or role |
| `relationships` | Other character names mapped to relationship descriptions |

### Body Sections

| Section | Description |
|---------|-------------|
| Personality | Personality traits, tendencies, motivations |
| Voice Pattern | How the character speaks, with examples |
| Current Arc | The character's growth trajectory in the story |

## Scene File Format

```markdown
---
scene_number: 1
scene_name: "The Gym Wars"
week: 1
location: "Riverside High gymnasium"
characters:
  - Marcus
  - Jamie
  - Tyler
  - Alex
  - Benny
  - Zoe
tone: Comedic, chaotic, energetic
key_moments:
  - "Marcus and Jamie bond over finding the scheduling bug"
  - "Tyler and Alex's hands linger during a collision"
---

## Context

Tyler's soccer team and Alex's basketball team both arrive
for practice at the same time due to a scheduling error.

## Scene Objectives

**Marcus:** Solve the scheduling conflict using logic and data.

**Jamie:** Find and fix the bug in the scheduling system.

**Tyler:** Get gym time without being a jerk about it.

**Alex:** Secure gym time for basketball practice.

**Benny:** Make everyone laugh. Defuse the tension.

**Zoe:** Provide dramatic narration of events.

## Beat Structure

1. **The Standoff** (2 minutes) -- Both teams arrive. Tension builds.
2. **The Negotiators** (3 minutes) -- Marcus mediates. Jamie debugs.
```

### Front Matter Fields

| Field | Description |
|-------|-------------|
| `scene_number` | Numeric identifier |
| `scene_name` | Display name for the scene |
| `week` | Timeline position (for multi-week stories) |
| `location` | Where the scene takes place |
| `characters` | List of character names (must match character filenames) |
| `tone` | Emotional quality of the scene |
| `key_moments` | Important events that should occur |

### Body Sections

| Section | Description |
|---------|-------------|
| Context | Narrative setup and situation |
| Scene Objectives | Per-character goals for the scene |
| Beat Structure | Sequence of dramatic beats with timing |

## Character Directory Auto-Detection

When you run `wr direct scenes/scene_01.md`, WritersRoom locates characters automatically:

1. If `--characters` flag is provided, use that path
2. If the scene is inside a `scenes/` directory, look for a sibling `characters/` directory
3. Fall back to `characters/` in the current directory

This means you can run scenes from inside a project directory without specifying the character path:

```bash
cd my_project
wr direct scenes/scene_01_opening.md
```

## Example Project: teen_play

The included `projects/teen_play/` demonstrates a complete project:

```
projects/teen_play/
  config.yml                          # provider: ollama, model_name: gpt-oss
  project.md                          # "Love by the Numbers" metadata
  characters/
    marcus.md                         # The analytical math whiz
    jamie.md                          # The logical robotics president
    tyler.md                          # The sensitive soccer captain
    alex.md                           # The intense basketball captain
    benny.md                          # The insecure class clown
    zoe.md                            # The theatrical drama kid
  scenes/
    scene_01_gym_wars.md              # All 6 characters meet (Week 1)
    scene_02_statistical_anomaly.md   # Marcus, Jamie, Benny (Week 2)
    scene_04_equipment_room.md        # Benny & Zoe breakthrough (Week 6)
    scene_08_data_dump.md             # Finale, all 6 characters (Week 16)
```

Run a teen_play scene:

```bash
wr direct projects/teen_play/scenes/scene_01_gym_wars.md --max-lines 30
```
