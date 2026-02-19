# Architecture

TODO: Document system design, class hierarchy, and how Director, Actor, Producer, and Writer interact.

## Prompt Templates

LLM prompts are externalized as prompt_manager templates in `lib/writers_room/prompts/`:

- `actor_system.md` -- System prompt for character actors
- `actor_dialog.md` -- User prompt for dialog generation
- `develop_concept.md` -- Concept development
- `develop_character.md` -- Character profile development
- `create_arc.md` -- Story arc creation
- `breakdown_scenes.md` -- Scene breakdown from arcs

Templates use markdown with YAML front matter and ERB interpolation. Project-level `prompts/` directories override gem defaults.
