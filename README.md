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

## Usage

```bash
wr init my_project --concept "A comedy about two rival chefs"
cd my_project

wr write develop-concept
wr write develop-character "Chef Marco" --personality "fiery perfectionist"
wr write create-arc "Act 1" --description "The rival chefs are forced to share a kitchen"
wr write breakdown-scenes "Act 1"

wr character create "Chef Marco" --personality "perfectionist" --speaking-style "passionate"
wr scene create "Kitchen Clash" --description "First day sharing" --characters Marco Luna

wr direct scenes/kitchen_clash.md
wr produce
wr report
```

Use `--chat` on any write command for interactive conversation with the LLM.

All project files are markdown with YAML front matter. The only exception is `config.yml`.

## Documentation

See the [docs/](docs/) directory:

- [Getting Started](docs/user/getting_started.md)
- [Project Structure](docs/user/project_structure.md)
- [Configuration](docs/user/configuration.md)
- [Quick Reference](docs/user/quick_reference.md)

## License

MIT
