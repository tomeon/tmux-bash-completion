#!/usr/bin/env bash

_tmux () {

    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    local flags='2Cc:f:L:lS:uvV'

    # Scan existing argument list for non-flag options
    if (( COMP_CWORD > 0 )); then
        local cmd=''
        local -i comp_iword=1
        local maybe_cmd="${COMP_WORDS[comp_iword]}"

        while (( comp_iword < COMP_CWORD )); do
            if [[ "$maybe_cmd" != *- ]]; then
                cmd="$maybe_cmd"
                break
            fi
            ((comp_iword++))
            maybe_cmd="${COMP_WORDS[comp_iword]}"
        done
    fi

    _tmux::lscm () {
        local wanted_cmd="$1"
        shift

        local cmd alias
        local -a lscm_output=()
        while read -ra lscm_output; do
            set -- "${lscm_output[@]}"
            # The full command name is the first field in each line of lscm
            cmd="$1"
            shift

            # tmux aliases are surrounded with parentheses
            if [[ "$1" == '('*')' ]]; then
                alias="${1//[()]/}"
                shift
            fi

            # If no command is sought, echo the command and its alias and return
            # without processing the command's options
            if [[ -z "${wanted_cmd:-}" ]]; then
                echo "$cmd" "$alias"
                continue
            # If a command was specified and it does not match the current
            # command, skip to the next iteration
            elif [[ "${wanted_cmd:-}" != "$cmd" ]]; then
                continue
            fi

            # Now process any flags
            local optv opt
            while (( $# )); do
                opt="$1"
                # All options are surrounded with square brackets and begin with a
                # single dash
                if [[ "$opt" != '[-'* ]]; then
                    shift
                # If $opt doesn't end with a square bracket, it takes an argument
                elif [[ "$opt" != *']' ]]; then
                    # Trim the opening bracket and append a colon to indicate that
                    # this option takes an argument
                    optv+=("${opt#[}:")

                    # Remove both the option and the argument from $@
                    shift 2
                else
                    # Remove opening all bracket, as well as all dashes.  Safe
                    # because all tmux options are single letters (i.e., no
                    # --long-options)
                    opt="${opt#[}"
                    opt="${opt//-/}"

                    # Some options are pipe-delimited
                    opt="${opt//|/}"

                    # Process each character separately
                    local flag
                    while read -n 1 flag; do
                        [[ -z "$flag" ]] && continue
                        optv+=("-$flag")
                    done <<<"${opt%]}"

                    shift
                fi
            done

            echo "${optv[@]}"
            break
        done < <(command tmux lscm)

        return 0
    }

    # If we haven't seen a command yet, provide completion based only on
    # commands and flags to tmux itself.
    if [[ -z "$cmd" ]]; then
        COMPREPLY=($(compgen -W "$(_tmux::lscm)" -- "${cur}"))
    else
        local -a optv
        optv=($(_tmux::lscm "$cmd"))

        if [[ "$prev" == -* ]]; then
            local flag trimmed
            for flag in "${optv[@]}"; do
                trimmed="${flag%:}"
                if [[ "$prev" == "$trimmed" ]] && (( ${#trimmed} < ${#flag} )); then
                    return 1
                fi
            done
        fi

        COMPREPLY=($(compgen -W "${optv[*]//:/}" -- "${cur}"))
    fi

    # Minimize environment pollution.
    unset -f _tmux::lscm

    return 0
}

complete -F _tmux tmux
