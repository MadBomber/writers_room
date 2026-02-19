# Architecture

WritersRoom is built on top of [RobotLab](https://github.com/madbomber/robot_lab) and follows its patterns for template-driven prompts, tool-based agency, bus messaging, and shared memory.

## Core Classes

### Room (`lib/writers_room/room.rb`)

The central container for a scene session. Holds the bus, shared memory, actor roster, and display output.

- Creates a `TypedBus::MessageBus` with a `:scene` channel
- Creates a `RobotLab::Memory` instance shared by all actors
- `add_actor` instantiates an Actor with template, tools, and bus subscriptions
- `seed` sends the opening prompt to the first actor
- `wait_for_completion` polls shared memory for `:scene_complete` or max line count
- `assemble_transcript` reads `:dialog_history` from shared memory

### Actor (`lib/writers_room/actor.rb`)

Extends `RobotLab::Robot`. Each Actor represents a character in a scene.

- Uses `template: :actor_system` with a `context:` hash built from character data
- Equipped with five local tools: `SpeakTool`, `ReadMemoryTool`, `WriteMemoryTool`, `ListMemoryTool`, `MarkSceneCompleteTool`
- Subscribes to the `:scene` bus channel via `setup_room_subscription`
- On each incoming bus message, calls `fresh_chat!` then `run` to generate a response
- `fresh_chat!` resets the chat context between turns (shared memory is the persistence layer)

### Director (`lib/writers_room/director.rb`)

Orchestrates a scene by assembling a Room, loading character and scene files, and managing the production lifecycle.

- Loads scene files (`.md` with front matter) via `FrontMatter.load_file`
- Creates a `Room` with `Display`, `Config`, and scene info
- Calls `room.seed` with an opening prompt then `room.wait_for_completion`
- Saves transcripts from `room.assemble_transcript`
- Uses `LLMSetup.build_run_config` for shared LLM configuration

### Producer (`lib/writers_room/producer.rb`)

Project-level operations: creating projects, characters, scenes, and running full productions.

- Writes `.md` files with YAML front matter via `FrontMatter.dump`
- Globs `*.md` for listing characters, scenes, etc.
- Delegates scene direction to `Director`

### Writer (`lib/writers_room/writer.rb`)

Story development tools that use LLM assistance via RobotLab templates.

- Each method (`develop_concept`, `develop_character`, `create_arc`, `breakdown_scenes`) calls `@robot.update(template:, context:)` then `.run`
- Uses `LLMSetup.build_run_config` for shared configuration
- `--chat` mode adds `RobotLab::AskUser` as a local tool

### ChatSession (`lib/writers_room/chat_session.rb`)

Interactive LLM chat sessions with project context. Uses `LLMSetup` for configuration. Accepts an optional `template:` parameter for template-based conversations.

## Support Classes

### FrontMatter (`lib/writers_room/front_matter.rb`)

Parses and generates Markdown files with YAML front matter.

- `FrontMatter.parse(content)` returns `{ metadata: Hash, body: String }`
- `FrontMatter.load_file(path)` reads from disk
- `FrontMatter.dump(metadata, body)` renders back to string

### LLMSetup (`lib/writers_room/llm_setup.rb`)

Shared LLM configuration. Eliminates duplication between Writer and ChatSession.

- `LLMSetup.configure_ruby_llm(config)` sets up provider-specific RubyLLM configuration
- `LLMSetup.build_run_config(config)` returns a `RobotLab::RunConfig`

### Display (`lib/writers_room/display.rb`)

Terminal output formatting with per-character ANSI color rotation and optional file logging.

### ProjectMetadata (`lib/writers_room/project_metadata.rb`)

Reads and writes `project.md` (front matter format).

## Tools

All tools are `RobotLab::Tool` subclasses in `lib/writers_room/tools/`. Zeitwerk collapses the directory so they live in the `WritersRoom` namespace directly.

| Tool | Purpose |
|------|---------|
| `SpeakTool` | Broadcast dialog to the `:scene` bus channel and record in shared memory |
| `ReadMemoryTool` | Read a value from shared memory |
| `WriteMemoryTool` | Write a value to shared memory |
| `ListMemoryTool` | List all keys in shared memory |
| `MarkSceneCompleteTool` | Signal that the scene is finished |

## Prompt Templates

LLM prompts are externalized as prompt_manager templates in `lib/writers_room/prompts/`:

- `actor_system.md` -- System prompt for character actors (includes tool usage instructions)
- `actor_dialog.md` -- User prompt for dialog generation
- `develop_concept.md` -- Concept development
- `develop_character.md` -- Character profile development
- `create_arc.md` -- Story arc creation
- `breakdown_scenes.md` -- Scene breakdown from arcs

Templates use Markdown with YAML front matter and ERB interpolation (`<%= parameter %>`). The `ROBOT_LAB_TEMPLATE_PATH` environment variable points RobotLab's prompt_manager to the templates directory. Project-level `prompts/` directories can override gem defaults.

## Message Flow (Scene Direction)

```
Director
  └─ creates Room (bus + memory + display)
       ├─ adds Actor "Alice" (template + tools + bus subscription)
       └─ adds Actor "Bob"   (template + tools + bus subscription)

Room.seed("Opening prompt")
  └─ Actor "Alice".run(prompt)
       └─ LLM calls SpeakTool(dialog: "Hi Bob!")
            ├─ writes to shared memory :dialog_history
            └─ broadcasts to :scene channel
                 └─ Actor "Bob" receives message
                      └─ fresh_chat! + run(message)
                           └─ LLM calls SpeakTool(dialog: "Hey Alice!")
                                └─ ... continues until max_lines or MarkSceneCompleteTool
```

## File Format

All project files use Markdown with YAML front matter:

```markdown
---
name: Alice
personality: cheerful
speaking_style: casual
---

## Background
Alice grew up in a small town...
```

All project files use this format exclusively.
