# Extending WritersRoom

## Adding a New CLI Command

1. Create a Thor subclass in `lib/writers_room/cli/`:

```ruby
module WritersRoom
  module Commands
    class MyCommand < Thor
      namespace "my_command"

      desc "my_action", "Description"
      def my_action
        # implementation
      end
    end
  end
end
```

2. Register it in `lib/writers_room/cli.rb` as a subcommand:

```ruby
desc "my_command SUBCOMMAND", "Description"
subcommand "my_command", Commands::MyCommand
```

3. Add help text in `lib/writers_room/help_formatter.rb`.

Note: The `cli/` directory is ignored by Zeitwerk and loaded manually via `autoload` or `require_relative`. Add an `autoload` entry in `cli.rb` if your command should be lazy-loaded.

## Adding a New Element Type

Element types are registered dynamically in `lib/writers_room/cli.rb`:

```ruby
%w[chapter arc location setting relationship theme].each do |type|
  require_relative "cli/element"
  desc "#{type} SUBCOMMAND", "Manage #{type}s (create, list, show, version, status)"
  subcommand type, Commands::Element.for_type(type)
end
```

To add a new element type (e.g., `episode`):

1. Add it to the array in `cli.rb`
2. Create an element template in `lib/writers_room/element_templates/episode.yml` (optional)
3. Add the corresponding directory to relevant media YAML configs in `lib/writers_room/config/media/`

`Element.for_type` creates a named constant under `Commands` (e.g., `Commands::Episode`) with a proper namespace for clean `wr tree` display.

## Adding a New Medium Type

Media types are defined by YAML config files in `lib/writers_room/config/media/`.

1. Create a new YAML file (e.g., `lib/writers_room/config/media/podcast.yml`):

```yaml
id: podcast
label: Podcast
universal_elements:
  - character
  - setting
  - theme
specific_elements:
  episode:
    singular: episode
    dir: episodes
  segment:
    singular: segment
    dir: segments
scaffolded_dirs:
  - characters
  - settings
  - episodes
  - segments
  - transcripts
workflows:
  - develop
  - direct
  - produce
statuses:
  - outline
  - draft
  - revision
  - polish
  - final
```

2. The `MediumRegistry` auto-discovers YAML files in the media directory. No code changes needed.

3. Add any new element types to the CLI registration array in `cli.rb` if they need their own subcommands.

## Adding a New Tool

Tools give actors agency during scene direction. Create a `RobotLab::Tool` subclass in `lib/writers_room/tools/`:

```ruby
module WritersRoom
  class MyTool < RobotLab::Tool
    description "What this tool does"

    param :input, desc: "Parameter description", required: true

    def execute(input:)
      # Access the owning robot via `robot`
      # Access shared memory via `robot.shared_memory`
      "Result string returned to the LLM"
    end
  end
end
```

Zeitwerk collapses the `tools/` directory, so the class lives in the `WritersRoom` namespace directly (e.g., `WritersRoom::MyTool`).

To make the tool available to actors, add it to the `local_tools:` array in `Actor#initialize` or `Room#add_actor`.

## Adding a New Prompt Template

1. Create a Markdown file in `lib/writers_room/prompts/`:

```markdown
---
description: What this template does
parameters:
  - name
  - context
---

You are a <%= name %>.

<%= context %>
```

2. Reference it by symbol name (filename without extension) in robot setup:

```ruby
robot.update(template: :my_template, context: { name: "value", context: "..." })
```

## Adding a New Export Formatter

Export formatters live in `lib/writers_room/formatters/`. Create a subclass of `BaseFormatter`:

```ruby
module WritersRoom
  module Formatters
    class MyFormatter < BaseFormatter
      def export(output_path)
        # Build formatted content from project files
        # Write to output_path
      end
    end
  end
end
```

Register the formatter in `Export#select_formatter` in `lib/writers_room/cli/export.rb`.

## Supporting a New LLM Provider

RubyLLM handles provider abstraction. To add a new provider:

1. Ensure RubyLLM supports the provider (or contribute support upstream)
2. Add the provider configuration in `LLMSetup.configure_ruby_llm`
3. Document the required environment variables in `docs/user/configuration.md`
