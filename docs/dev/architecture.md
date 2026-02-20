# Architecture

WritersRoom is built on top of [RobotLab](https://github.com/madbomber/robot_lab) and follows its patterns for template-driven prompts, tool-based agency, bus messaging, and shared memory.

## Autoloading

WritersRoom uses Zeitwerk for autoloading with a few special configurations:

- `"llm_setup" => "LLMSetup"` and `"cli" => "CLI"` inflections
- `cli/`, `config/`, `element_templates/`, and `prompts/` directories are ignored (loaded manually or used as data)
- `tools/` directory is collapsed so tool classes live in the `WritersRoom` namespace directly

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
- Equipped with local tools: `SpeakTool`, `ReadMemoryTool`, `WriteMemoryTool`, `ListMemoryTool`, `MarkSceneCompleteTool`
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

- `Producer.create_project` initializes a project with metadata, config, and scaffolded directories
- `ensure_project_structure` calls `ProjectScaffolder#scaffold!` to create directories and story bible
- `create_character` and `create_scene` use `FileUtils.mkdir_p` so they work even when the target directory is not in the medium's scaffolded dirs
- Delegates scene direction to `Director`

### Writer (`lib/writers_room/writer.rb`)

Story development tools that use LLM assistance via RobotLab templates.

- Each method (`develop_concept`, `develop_character`, `create_arc`, `breakdown_scenes`) calls `@robot.update(template:, context:)` then `.run`
- Uses `LLMSetup.build_run_config` for shared configuration
- `--chat` mode creates a `ChatSession` and runs it through `ChatTui`

### ChatSession (`lib/writers_room/chat_session.rb`)

Interactive LLM chat sessions with project context. Uses `LLMSetup` for configuration. Accepts an optional `template:` parameter for template-based conversations.

### ChatTui (`lib/writers_room/chat_tui.rb`)

Terminal UI for interactive chat. Takes a `ChatSession` and handles input/output with streaming display. The TUI owns the interactive loop; `ChatSession` owns business logic.

## Medium System

### MediumRegistry (`lib/writers_room/medium_registry.rb`)

Registry of available medium types. Lazy-loads from YAML config files in `lib/writers_room/config/media/`.

- `MediumRegistry.find(:novella)` returns a `Medium` instance
- `MediumRegistry.all` returns all available media
- `MediumRegistry.ids` returns all registered medium symbols

### Medium (`lib/writers_room/medium.rb`)

Data class representing a creative writing medium type. Each medium defines:

| Attribute | Description |
|-----------|-------------|
| `id` | Symbol identifier (`:novella`, `:screenplay`, etc.) |
| `label` | Human-readable name |
| `universal_elements` | Elements shared across all media (characters, settings, etc.) |
| `specific_elements` | Elements unique to this medium (chapters for novel, episodes for TV) |
| `scaffolded_dirs` | Directories created by `wr init` |
| `workflows` | Available workflow types |
| `statuses` | Valid status progression (outline, draft, revision, polish, final) |

Media are configured via YAML files in `lib/writers_room/config/media/`. There are 9 media types: dialog, documentary, novel, novella, radio_play, screenplay, short_story, stage_play, tv_series.

### ProjectScaffolder (`lib/writers_room/project_scaffolder.rb`)

Creates project directory structure based on medium type.

- `scaffold!` creates directories, then creates `story_bible.yml`
- Called by `Producer#ensure_project_structure` and during `wr init`

## Element System

### Element (`lib/writers_room/element.rb`)

Lightweight value object wrapping a FrontMatter file. Represents any story element.

- `Element.load(path)` reads and parses a file
- `Element.create(dir, name, metadata:, body:)` creates a new element file with `mkdir_p`
- `element.save` writes back to disk
- `element.matches_name?(query)` checks slug, name, and aliases

### ElementCollection (`lib/writers_room/element_collection.rb`)

Manages all elements of a given type within a directory.

- `all` loads elements, excluding version files (`_v\d+.md`)
- `find_by_slug`, `find_by_name_or_alias`, `search` for lookups
- `create` delegates to `Element.create`
- `count` excludes version files

### Versioner (`lib/writers_room/versioner.rb`)

Manages file versioning. Creates `slug_v1.md`, `slug_v2.md`, etc.

- `versions` returns all version files sorted by number
- `create_new_version` copies from a base file, increments version number
- `version_at(n)` loads a specific version

## Story Bible and Cross-References

### StoryBible (`lib/writers_room/story_bible.rb`)

Auto-generated YAML index mapping element slugs/aliases to files.

- `regenerate` scans all scaffolded directories using `ElementCollection`
- `resolve` does exact matching first, then substring fallback
- `pin_version` / `unpin_version` for version pinning

### CrossReference (`lib/writers_room/cross_reference.rb`)

Scans element bodies for name/alias references and builds a reference graph.

- `scan` loads all elements, builds a name map, finds word-boundary matches
- `graph` returns `{ nodes: [...], edges: [{ from:, to: }] }`
- `references_for(slug)` and `referenced_by(slug)` for directed lookups

## Project State and Workflow

### ContextDetector (`lib/writers_room/context_detector.rb`)

Inspects the current working directory to determine project context. Walks up the directory tree looking for `project.md`.

Returns a `Context` struct with: `project_path`, `medium`, `element_type`, `project_state`, `in_project?`.

### ProjectState (`lib/writers_room/project_state.rb`)

Summarizes project state: element counts (excluding version files), missing/empty directories, workflow stage.

Stages: `:empty`, `:concept_only`, `:populating`, `:developing`.

### Workflow (`lib/writers_room/workflow.rb`)

Manages workflow progression for a medium type. Validates status transitions and provides next-step suggestions.

Status order: `outline` -> `draft` -> `revision` -> `polish` -> `final`.

## Export Formatters

Located in `lib/writers_room/formatters/`:

| Formatter | Used For |
|-----------|----------|
| `BaseFormatter` | Default, generic export |
| `NovelFormatter` | Novel, novella, short story |
| `ScreenplayFormatter` | Screenplay, stage play |
| `TranscriptFormatter` | Dialog-oriented media |

Selected automatically by `Export#select_formatter` based on medium type.

## Support Classes

### FrontMatter (`lib/writers_room/front_matter.rb`)

Parses and generates Markdown files with YAML front matter.

- `FrontMatter.parse(content)` returns `{ metadata: Hash, body: String }`
- `FrontMatter.load_file(path)` reads from disk
- `FrontMatter.dump(metadata, body)` renders back to string (handles nil body safely)

### LLMSetup (`lib/writers_room/llm_setup.rb`)

Shared LLM configuration. Eliminates duplication between Writer and ChatSession.

- `LLMSetup.configure_ruby_llm(config)` sets up provider-specific RubyLLM configuration
- `LLMSetup.build_run_config(config)` returns a `RobotLab::RunConfig`

### Display (`lib/writers_room/display.rb`)

Terminal output formatting with per-character ANSI color rotation and optional file logging.

### ProjectMetadata (`lib/writers_room/project_metadata.rb`)

Reads and writes `project.md` (front matter format). Provides `name`, `concept`, `medium` accessors.

### AliasResolver (`lib/writers_room/alias_resolver.rb`)

Resolves character names and aliases to file paths.

### SourceMaterial (`lib/writers_room/source_material.rb`)

Handles importing source material from other projects or files.

### MarkdownRenderer (`lib/writers_room/markdown_renderer.rb`)

Renders markdown content for terminal display.

### HelpFormatter (`lib/writers_room/help_formatter.rb`)

Generates comprehensive help output for `wr help --verbose`.

## Tools

All tools are `RobotLab::Tool` subclasses in `lib/writers_room/tools/`. Zeitwerk collapses the directory so they live in the `WritersRoom` namespace directly.

| Tool | Purpose |
|------|---------|
| `SpeakTool` | Broadcast dialog to the `:scene` bus channel and record in shared memory |
| `ReadMemoryTool` | Read a value from shared memory |
| `WriteMemoryTool` | Write a value to shared memory |
| `ListMemoryTool` | List all keys in shared memory |
| `MarkSceneCompleteTool` | Signal that the scene is finished |
| `ReadFileTool` | Read a file from the project |
| `WriteFileTool` | Write a file to the project |
| `ListDirectoryTool` | List files in a project directory |
| `ProjectTool` | Access project metadata and configuration |

## CLI Structure

The CLI uses Thor. All subcommand classes live under `WritersRoom::Commands`:

- `CLI` (main) -- registered as `wr`, default task is `chat`
- `Write` -- writer tools (`develop-concept`, etc.)
- `Character` -- character CRUD
- `Scene` -- scene CRUD
- `Bible` -- story bible management
- `Export` -- manuscript, bible, and reference export
- `Element` -- generic element CRUD, dynamically subclassed via `Element.for_type(type)`

Dynamic element subcommands (chapter, arc, location, setting, relationship, theme) are registered at load time. `Element.for_type` creates a named subclass under `Commands` with a proper `namespace` for clean `wr tree` display.

## Prompt Templates

LLM prompts are externalized as RobotLab templates in `lib/writers_room/prompts/`:

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
  +-- creates Room (bus + memory + display)
       +-- adds Actor "Alice" (template + tools + bus subscription)
       +-- adds Actor "Bob"   (template + tools + bus subscription)

Room.seed("Opening prompt")
  +-- Actor "Alice".run(prompt)
       +-- LLM calls SpeakTool(dialog: "Hi Bob!")
            +-- writes to shared memory :dialog_history
            +-- broadcasts to :scene channel
                 +-- Actor "Bob" receives message
                      +-- fresh_chat! + run(message)
                           +-- LLM calls SpeakTool(dialog: "Hey Alice!")
                                +-- ... continues until max_lines or MarkSceneCompleteTool
```
