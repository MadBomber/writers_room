#!/usr/bin/env bash
# Bash completion for wr (WritersRoom CLI)
# Install: Copy to /usr/local/etc/bash_completion.d/ or source in ~/.bashrc

_wr_completions() {
    local cur prev commands
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Main commands
    local main_commands="actor character config direct help init produce report scene version write"

    # Subcommands for each main command
    local write_commands="breakdown-scenes create-arc develop-character develop-concept list-arcs"
    local character_commands="create list"
    local scene_commands="create list"

    # Options
    local init_options="--provider -p --model -m --concept -c"
    local direct_options="--characters -c --output -o --max-lines -l"
    local produce_options="--max-lines -l --output -o --chat"
    local actor_options="--channel -r"
    local character_create_options="--personality -p --speaking-style -s --background -b"
    local scene_create_options="--description -d --characters -c"
    local write_develop_character_options="--personality -p --background -b --chat"
    local write_create_arc_options="--description -d --chat"
    local write_breakdown_options="--num-scenes -n --chat"
    local write_develop_concept_options="--chat"

    # Get the main command (first argument after 'wr')
    local main_cmd=""
    local sub_cmd=""

    if [ ${#COMP_WORDS[@]} -gt 1 ]; then
        main_cmd="${COMP_WORDS[1]}"
    fi

    if [ ${#COMP_WORDS[@]} -gt 2 ]; then
        sub_cmd="${COMP_WORDS[2]}"
    fi

    # Complete main commands
    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=( $(compgen -W "${main_commands}" -- ${cur}) )
        return 0
    fi

    # Complete subcommands and options based on main command
    case "${main_cmd}" in
        write)
            if [ $COMP_CWORD -eq 2 ]; then
                COMPREPLY=( $(compgen -W "${write_commands}" -- ${cur}) )
            else
                case "${sub_cmd}" in
                    develop-concept)
                        COMPREPLY=( $(compgen -W "${write_develop_concept_options}" -- ${cur}) )
                        ;;
                    develop-character)
                        if [[ ${cur} == -* ]]; then
                            COMPREPLY=( $(compgen -W "${write_develop_character_options}" -- ${cur}) )
                        fi
                        ;;
                    create-arc)
                        COMPREPLY=( $(compgen -W "${write_create_arc_options}" -- ${cur}) )
                        ;;
                    breakdown-scenes)
                        if [[ ${cur} == -* ]]; then
                            COMPREPLY=( $(compgen -W "${write_breakdown_options}" -- ${cur}) )
                        elif [ "${prev}" = "breakdown-scenes" ]; then
                            # Complete with available arc names from project.yml
                            if [ -f "project.yml" ]; then
                                local arcs=$(grep -A 1 "^  - name:" project.yml 2>/dev/null | grep "name:" | sed 's/.*name: //' | tr '\n' ' ')
                                COMPREPLY=( $(compgen -W "${arcs}" -- ${cur}) )
                            fi
                        fi
                        ;;
                esac
            fi
            ;;
        character)
            if [ $COMP_CWORD -eq 2 ]; then
                COMPREPLY=( $(compgen -W "${character_commands}" -- ${cur}) )
            elif [ "${sub_cmd}" = "create" ] && [[ ${cur} == -* ]]; then
                COMPREPLY=( $(compgen -W "${character_create_options}" -- ${cur}) )
            fi
            ;;
        scene)
            if [ $COMP_CWORD -eq 2 ]; then
                COMPREPLY=( $(compgen -W "${scene_commands}" -- ${cur}) )
            elif [ "${sub_cmd}" = "create" ] && [[ ${cur} == -* ]]; then
                COMPREPLY=( $(compgen -W "${scene_create_options}" -- ${cur}) )
            fi
            ;;
        init)
            if [[ ${cur} == -* ]]; then
                COMPREPLY=( $(compgen -W "${init_options}" -- ${cur}) )
            fi
            ;;
        direct)
            if [[ ${cur} == -* ]]; then
                COMPREPLY=( $(compgen -W "${direct_options}" -- ${cur}) )
            elif [ "${prev}" = "direct" ]; then
                # Complete with scene files
                COMPREPLY=( $(compgen -f -X '!*.yml' -- ${cur}) )
            fi
            ;;
        actor)
            if [[ ${cur} == -* ]]; then
                COMPREPLY=( $(compgen -W "${actor_options}" -- ${cur}) )
            elif [ $COMP_CWORD -eq 2 ] || [ $COMP_CWORD -eq 3 ]; then
                # Complete with yml files
                COMPREPLY=( $(compgen -f -X '!*.yml' -- ${cur}) )
            fi
            ;;
        produce)
            if [[ ${cur} == -* ]]; then
                COMPREPLY=( $(compgen -W "${produce_options}" -- ${cur}) )
            else
                # Complete with scene files
                COMPREPLY=( $(compgen -f -X '!*.yml' -- ${cur}) )
            fi
            ;;
        help)
            if [ $COMP_CWORD -eq 2 ]; then
                COMPREPLY=( $(compgen -W "${main_commands}" -- ${cur}) )
            fi
            ;;
    esac

    return 0
}

# Register completion
complete -F _wr_completions wr
