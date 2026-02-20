# WritersRoom Shell Completions

Tab completion scripts for the `wr` command in bash, zsh, and fish.

## Quick Install

**Bash:**
```bash
cp wr.bash /usr/local/etc/bash_completion.d/wr
source ~/.bashrc
```

**Zsh:**
```bash
cp _wr /usr/local/share/zsh/site-functions/_wr
rm -f ~/.zcompdump && compinit
```

**Fish:**
```bash
cp wr.fish ~/.config/fish/completions/wr.fish
```

## Files

- `wr.bash` - Bash completion script
- `_wr` - Zsh completion script
- `wr.fish` - Fish completion script
- `INSTALL.md` - Detailed installation instructions
- `README.md` - This file

## Features

✅ Complete all commands and subcommands
✅ Complete command-line options
✅ Complete file paths (`.yml` files)
✅ Complete project data (arc names)
✅ Context-aware suggestions
✅ Rich descriptions (zsh/fish)

## Usage

```bash
# See available commands
wr <TAB>

# See write subcommands
wr write <TAB>

# See options for a command
wr write develop-concept --<TAB>

# Complete scene files
wr direct scenes/<TAB>

# Complete arc names (inside a project)
wr write breakdown-scenes <TAB>
```

## Documentation

See [INSTALL.md](INSTALL.md) for detailed installation instructions, troubleshooting, and advanced usage.

## Testing

After installation, test completions:

```bash
wr <TAB>                           # Should show main commands
wr write <TAB>                     # Should show write subcommands
wr write develop-concept --<TAB>   # Should show --chat option
```

## Support

For issues or questions:
- Check [INSTALL.md](INSTALL.md) for troubleshooting
- Open an issue on GitHub
- Check your shell's completion system is working
