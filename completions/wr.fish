# Fish completion for wr (WritersRoom CLI)
# Install: Copy to ~/.config/fish/completions/ or /usr/share/fish/completions/

# Disable file completion by default
complete -c wr -f

# Main commands
complete -c wr -n "__fish_use_subcommand" -a "actor" -d "Run a single actor"
complete -c wr -n "__fish_use_subcommand" -a "character" -d "Manage characters"
complete -c wr -n "__fish_use_subcommand" -a "config" -d "Show configuration"
complete -c wr -n "__fish_use_subcommand" -a "direct" -d "Direct a scene"
complete -c wr -n "__fish_use_subcommand" -a "help" -d "Show help"
complete -c wr -n "__fish_use_subcommand" -a "init" -d "Initialize project"
complete -c wr -n "__fish_use_subcommand" -a "produce" -d "Run production"
complete -c wr -n "__fish_use_subcommand" -a "report" -d "Generate report"
complete -c wr -n "__fish_use_subcommand" -a "scene" -d "Manage scenes"
complete -c wr -n "__fish_use_subcommand" -a "version" -d "Show version"
complete -c wr -n "__fish_use_subcommand" -a "write" -d "Writer tools"

# write subcommands
complete -c wr -n "__fish_seen_subcommand_from write; and not __fish_seen_subcommand_from breakdown-scenes create-arc develop-character develop-concept list-arcs" -a "breakdown-scenes" -d "Break down arc into scenes"
complete -c wr -n "__fish_seen_subcommand_from write; and not __fish_seen_subcommand_from breakdown-scenes create-arc develop-character develop-concept list-arcs" -a "create-arc" -d "Create story arc"
complete -c wr -n "__fish_seen_subcommand_from write; and not __fish_seen_subcommand_from breakdown-scenes create-arc develop-character develop-concept list-arcs" -a "develop-character" -d "Develop character profile"
complete -c wr -n "__fish_seen_subcommand_from write; and not __fish_seen_subcommand_from breakdown-scenes create-arc develop-character develop-concept list-arcs" -a "develop-concept" -d "Develop project concept"
complete -c wr -n "__fish_seen_subcommand_from write; and not __fish_seen_subcommand_from breakdown-scenes create-arc develop-character develop-concept list-arcs" -a "list-arcs" -d "List story arcs"

# write develop-concept options
complete -c wr -n "__fish_seen_subcommand_from write; and __fish_seen_subcommand_from develop-concept" -l chat -d "Interactive chat mode"

# write develop-character options
complete -c wr -n "__fish_seen_subcommand_from write; and __fish_seen_subcommand_from develop-character" -s p -l personality -d "Personality description" -r
complete -c wr -n "__fish_seen_subcommand_from write; and __fish_seen_subcommand_from develop-character" -s b -l background -d "Background notes" -r
complete -c wr -n "__fish_seen_subcommand_from write; and __fish_seen_subcommand_from develop-character" -l chat -d "Interactive chat mode"

# write create-arc options
complete -c wr -n "__fish_seen_subcommand_from write; and __fish_seen_subcommand_from create-arc" -s d -l description -d "Arc description" -r
complete -c wr -n "__fish_seen_subcommand_from write; and __fish_seen_subcommand_from create-arc" -l chat -d "Interactive chat mode"

# write breakdown-scenes options
complete -c wr -n "__fish_seen_subcommand_from write; and __fish_seen_subcommand_from breakdown-scenes" -s n -l num-scenes -d "Number of scenes" -r
complete -c wr -n "__fish_seen_subcommand_from write; and __fish_seen_subcommand_from breakdown-scenes" -l chat -d "Interactive chat mode"

# character subcommands
complete -c wr -n "__fish_seen_subcommand_from character; and not __fish_seen_subcommand_from create list" -a "create" -d "Create new character"
complete -c wr -n "__fish_seen_subcommand_from character; and not __fish_seen_subcommand_from create list" -a "list" -d "List characters"

# character create options
complete -c wr -n "__fish_seen_subcommand_from character; and __fish_seen_subcommand_from create" -s p -l personality -d "Personality" -r
complete -c wr -n "__fish_seen_subcommand_from character; and __fish_seen_subcommand_from create" -s s -l speaking-style -d "Speaking style" -r
complete -c wr -n "__fish_seen_subcommand_from character; and __fish_seen_subcommand_from create" -s b -l background -d "Background" -r

# scene subcommands
complete -c wr -n "__fish_seen_subcommand_from scene; and not __fish_seen_subcommand_from create list" -a "create" -d "Create new scene"
complete -c wr -n "__fish_seen_subcommand_from scene; and not __fish_seen_subcommand_from create list" -a "list" -d "List scenes"

# scene create options
complete -c wr -n "__fish_seen_subcommand_from scene; and __fish_seen_subcommand_from create" -s d -l description -d "Description" -r
complete -c wr -n "__fish_seen_subcommand_from scene; and __fish_seen_subcommand_from create" -s c -l characters -d "Characters" -r

# init options
complete -c wr -n "__fish_seen_subcommand_from init" -s p -l provider -d "LLM provider" -r -a "ollama openai anthropic"
complete -c wr -n "__fish_seen_subcommand_from init" -s m -l model -d "Model name" -r
complete -c wr -n "__fish_seen_subcommand_from init" -s c -l concept -d "Project concept" -r

# direct options
complete -c wr -n "__fish_seen_subcommand_from direct" -s c -l characters -d "Character directory" -r -F
complete -c wr -n "__fish_seen_subcommand_from direct" -s o -l output -d "Output file" -r -F
complete -c wr -n "__fish_seen_subcommand_from direct" -s l -l max-lines -d "Max lines" -r

# direct scene file completion
complete -c wr -n "__fish_seen_subcommand_from direct" -a "(__fish_complete_suffix .yml)"

# actor options
complete -c wr -n "__fish_seen_subcommand_from actor" -s r -l channel -d "Redis channel" -r

# actor file completions
complete -c wr -n "__fish_seen_subcommand_from actor" -a "(__fish_complete_suffix .yml)"

# produce options
complete -c wr -n "__fish_seen_subcommand_from produce" -s l -l max-lines -d "Max lines per scene" -r
complete -c wr -n "__fish_seen_subcommand_from produce" -s o -l output -d "Output directory" -r -F
complete -c wr -n "__fish_seen_subcommand_from produce" -l chat -d "Interactive chat mode"

# produce scene files completion
complete -c wr -n "__fish_seen_subcommand_from produce" -a "(__fish_complete_suffix .yml)"

# help command completion
complete -c wr -n "__fish_seen_subcommand_from help" -a "actor character config direct init produce report scene version write"
