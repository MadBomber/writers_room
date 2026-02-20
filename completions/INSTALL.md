# Shell Completion Installation

WritersRoom provides tab completion for bash, zsh, and fish shells. This enables autocompletion of commands, subcommands, options, and even project-specific data like arc names.

## Features

- Complete all `wr` commands and subcommands
- Complete command-line options with descriptions
- Complete file paths for scene and character files
- Complete arc names from your `project.yml` (zsh/bash)
- Smart context-aware completions

## Installation

### Bash

#### Option 1: System-wide Installation (macOS with Homebrew)

```bash
# Copy completion file to bash-completion directory
sudo cp completions/wr.bash /usr/local/etc/bash_completion.d/wr

# Restart your shell or source it
source /usr/local/etc/bash_completion.d/wr
```

#### Option 2: User-level Installation

```bash
# Create completions directory if it doesn't exist
mkdir -p ~/.bash_completion.d

# Copy completion file
cp completions/wr.bash ~/.bash_completion.d/wr

# Add to your ~/.bashrc or ~/.bash_profile
echo 'source ~/.bash_completion.d/wr' >> ~/.bashrc

# Reload your shell
source ~/.bashrc
```

#### Option 3: Direct Source in ~/.bashrc

```bash
# Add to your ~/.bashrc
echo "source $(pwd)/completions/wr.bash" >> ~/.bashrc

# Reload your shell
source ~/.bashrc
```

### Zsh

#### Option 1: System-wide Installation

```bash
# Copy to zsh completions directory
sudo cp completions/_wr /usr/local/share/zsh/site-functions/_wr

# Rebuild completion cache
rm -f ~/.zcompdump
compinit
```

#### Option 2: User-level Installation

```bash
# Create user completions directory
mkdir -p ~/.zsh/completions

# Copy completion file
cp completions/_wr ~/.zsh/completions/_wr

# Add to your ~/.zshrc (before compinit)
echo 'fpath=(~/.zsh/completions $fpath)' >> ~/.zshrc
echo 'autoload -Uz compinit && compinit' >> ~/.zshrc

# Reload your shell
source ~/.zshrc
```

#### Option 3: Oh-My-Zsh

```bash
# Copy to Oh-My-Zsh custom completions
mkdir -p ~/.oh-my-zsh/custom/plugins/wr
cp completions/_wr ~/.oh-my-zsh/custom/plugins/wr/_wr

# Add 'wr' to plugins in ~/.zshrc
# plugins=(git ... wr)

# Reload your shell
source ~/.zshrc
```

### Fish

#### Option 1: User Installation (Recommended)

```bash
# Create user completions directory
mkdir -p ~/.config/fish/completions

# Copy completion file
cp completions/wr.fish ~/.config/fish/completions/wr.fish

# Completions are automatically loaded by fish
```

#### Option 2: System-wide Installation

```bash
# Copy to system completions directory
sudo cp completions/wr.fish /usr/share/fish/vendor_completions.d/wr.fish
```

## Verification

After installation, verify that completions work:

### Bash/Zsh
```bash
# Type 'wr ' and press TAB - you should see available commands
wr <TAB>

# Type 'wr write ' and press TAB - you should see write subcommands
wr write <TAB>

# Type 'wr write develop-concept --' and press TAB - you should see options
wr write develop-concept --<TAB>
```

### Fish
```fish
# Same as above - fish will show completions with descriptions
wr <TAB>
```

## Features by Shell

### Bash Completions Include:
- All main commands
- All subcommands for `write`, `character`, `scene`
- All command-line options
- File completion for `.yml` files
- Arc name completion from `project.yml`

### Zsh Completions Include:
- All features from bash
- Rich descriptions for each command
- Categorized option groups
- Advanced context-aware completions
- Provider suggestions (ollama, openai, anthropic)

### Fish Completions Include:
- All features from bash
- Native fish syntax with descriptions
- Visual completion menu
- Smart file filtering

## Troubleshooting

### Bash

**Completions not working?**

1. Check if bash-completion is installed:
   ```bash
   brew install bash-completion  # macOS
   apt-get install bash-completion  # Linux
   ```

2. Verify bash-completion is sourced in your ~/.bashrc:
   ```bash
   # For macOS with Homebrew
   [[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"
   ```

3. Check file permissions:
   ```bash
   chmod +x completions/wr.bash
   ```

### Zsh

**Completions not working?**

1. Check if compinit is called in ~/.zshrc:
   ```bash
   autoload -Uz compinit && compinit
   ```

2. Rebuild completion cache:
   ```bash
   rm -f ~/.zcompdump*
   exec zsh
   ```

3. Check fpath includes the completion directory:
   ```bash
   echo $fpath
   ```

4. Verify the file starts with `#compdef wr`:
   ```bash
   head -1 completions/_wr
   ```

### Fish

**Completions not working?**

1. Check completions directory exists:
   ```bash
   ls ~/.config/fish/completions/
   ```

2. Reload fish configurations:
   ```fish
   source ~/.config/fish/config.fish
   ```

3. Check for errors:
   ```fish
   fish --debug-categories=complete
   ```

## Advanced Usage

### Project-Specific Completions

When inside a WritersRoom project directory:

```bash
# Tab completion will show your actual arc names
wr write breakdown-scenes <TAB>
# Shows: "Act 1", "Act 2", etc. (from your project.yml)
```

### File Completions

```bash
# Automatically filters to show only .yml files
wr direct scenes/<TAB>

# Shows only scene files
wr produce scenes/<TAB>
```

### Option Completions

```bash
# See all available options
wr write develop-character --<TAB>

# Shows:
# --personality  --background  --chat
```

## Updating Completions

When you update WritersRoom, you may need to update completions:

```bash
# Re-copy the completion file using the same method you used for installation
cp completions/wr.bash /usr/local/etc/bash_completion.d/wr  # Bash
cp completions/_wr /usr/local/share/zsh/site-functions/_wr  # Zsh
cp completions/wr.fish ~/.config/fish/completions/wr.fish   # Fish

# Reload your shell
source ~/.bashrc   # Bash
source ~/.zshrc    # Zsh
# Fish reloads automatically
```

## Uninstallation

### Bash
```bash
rm /usr/local/etc/bash_completion.d/wr
# or
rm ~/.bash_completion.d/wr
# Remove the source line from ~/.bashrc if you added it
```

### Zsh
```bash
rm /usr/local/share/zsh/site-functions/_wr
# or
rm ~/.zsh/completions/_wr
# Remove fpath line from ~/.zshrc if needed
rm ~/.zcompdump*
compinit
```

### Fish
```bash
rm ~/.config/fish/completions/wr.fish
```

## Contributing

If you find issues with completions or want to add new features:

1. Test your changes in all three shells
2. Update this INSTALL.md with any new instructions
3. Submit a pull request

## License

Same as WritersRoom (MIT)
