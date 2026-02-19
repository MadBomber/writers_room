# Extending WritersRoom

## Adding a New CLI Command

1. Create a Thor subclass in `lib/writers_room/cli/`:

```ruby
module WritersRoom
  module Commands
    class MyCommand < Thor
      desc "my_action", "Description"
      def my_action
        # implementation
      end
    end
  end
end
```

2. Register it in `lib/writers_room/cli.rb` as a subcommand.
3. Add help text in `lib/writers_room/help_formatter.rb`.

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

## Supporting a New LLM Provider

RubyLLM handles provider abstraction. To add a new provider:

1. Ensure RubyLLM supports the provider (or contribute support upstream)
2. Add the provider configuration in `LLMSetup.configure_ruby_llm`
3. Document the required environment variables in `docs/user/configuration.md`

## Adding a New File Format

WritersRoom uses Markdown with YAML front matter for all project files. The `FrontMatter` module handles parsing and generation:

```ruby
# Reading
parsed = WritersRoom::FrontMatter.load_file("path/to/file.md")
metadata = parsed[:metadata]  # Hash from YAML front matter
body = parsed[:body]           # String content after front matter

# Writing
content = WritersRoom::FrontMatter.dump(
  { name: "Alice", role: "protagonist" },
  "Character description here..."
)
File.write("characters/alice.md", content)
```

All project files use `.md` with front matter exclusively.
