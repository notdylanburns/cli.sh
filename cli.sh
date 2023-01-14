#!/bin/bash

validate_args_file() {
    if [[ -z "$CMD_ARGS_FILE" ]] ; then
        2>&1 echo "\$CMD_ARGS_FILE was expected to contain the path of a .args file"
        return 1
    fi

    if [[ ! -f "$CMD_ARGS_FILE" ]] ; then
        2>&1 echo "\$CMD_ARGS_FILE does not contain a valid path to an .args file"
        return 1
    fi

    if errors=$(grep -HnPv '^[a-zA-Z_][a-zA-Z0-9_-]*:(true|false):(-[a-zA-Z0-9])?:(--[a-zA-Z0-9]+)?:([0-9]+)?:.*$' "$CMD_ARGS_FILE") ; then
        2>&1 echo -e "\e[1;31mError:\e[0m invalid args file '${CMD_ARGS_FILE}'\n"

        echo "'''"
        local IFS=
        while read -r line; do
            2>&1 echo -e "\e[36m$(echo "$line" | sed -e 's/:/\\e[0m:\\e[32m/1' -e 's/:/\\e[0m:/2')"
        done <<< "$errors"
        echo "'''"

        return 1
    fi

    return 0
}

usage() {
    if [[ -z "$CMD_ARGS_FILE" ]] ; then
        2>&1 echo "\$CMD_ARGS_FILE was expected to contain the path of a .args file"
        return 1
    fi

    if [[ ! -f "$CMD_ARGS_FILE" ]] ; then
        2>&1 echo "\$CMD_ARGS_FILE does not contain a valid path to an .args file"
        return 1
    fi

    if ! validate_args_file "$CMD_ARGS_FILE" ; then
        2>&1 echo -e "\nArgs file validation failed"
        return 1
    fi

    2>&1 echo -n "Usage: $CMD_CALLED_AS [flags] "

    if positional_args="$(grep -P '^[a-zA-Z_][a-zA-Z0-9_-]*:(true|false)::::.*$' "$CMD_ARGS_FILE")" ; then

        for arg in "$positional_args" ; do
            name=$(echo "$arg" | cut -d: -f1)
            if [[ "$(echo "$arg" | cut -d: -f2)" == 'true' ]] ; then
                echo -n "<${name}> "
            else
                echo -n "[${name}] "
            fi
        done
        echo

        if [[ -n "$(echo $positional_args | tr -d ' ')" ]] ; then
            echo -e '\nPositional Arguments:'
        fi

    fi

    for arg in "$positional_args" ; do
        name=$(echo "$arg" | cut -d: -f1)
        short_desc=$(echo "$arg" | cut -d: -f6)
        printf "  %-*s%s\n" 20 "$name" "$short_desc"
    done

    flag_arguments="$(grep -P '^[a-zA-Z_][a-zA-Z0-9_-]*:(true|false):((-[a-zA-Z0-9]:)|(:--[a-zA-Z0-9]+)|(-[a-zA-Z0-9]:--[a-zA-Z0-9]+)):[0-9]+:.*$' "$CMD_ARGS_FILE" | sort -t: -k4)"

    if [[ "$(echo "$flag_arguments" | wc -l)" != '0' ]] ; then
        echo -e '\nFlags:'
    fi

    local IFS=
    while read -r arg; do
        short_form=$(echo "$arg" | cut -d: -f3)
        long_form=$(echo "$arg" | cut -d: -f4)
        short_desc=$(echo "$arg" | cut -d: -f6)
        printf "  %s,  %-*s%s" "$short_form" 15 "$long_form" "$short_desc"
        if [[ "$(echo "$arg" | cut -d: -f2)" == '1' ]] ; then
            echo -n " (required)"
        fi

        echo
    done <<< "$flag_arguments"

}

parse_args() {
    if [[ -z "$CMD_ARGS_FILE" ]] ; then
        2>&1 echo "\$CMD_ARGS_FILE was expected to contain the path of a .args file"
        return 1
    fi

    if [[ ! -f "$CMD_ARGS_FILE" ]] ; then
        2>&1 echo "\$CMD_ARGS_FILE does not contain a valid path to an .args file"
        return 1
    fi

    if ! validate_args_file "$CMD_ARGS_FILE" ; then
        2>&1 echo -e "\nArgs file validation failed"
        return 1
    fi

    passed_args=("$@")

    positional_count="$(grep -P '^[a-zA-Z_][a-zA-Z0-9_-]*:(true|false)::::.*$' "$CMD_ARGS_FILE" | wc -l)"
    seen_positional=0

    expected_flags="$(grep -P '^[a-zA-Z_][a-zA-Z0-9_-]*:true:(-[a-zA-Z0-9])?:(--[a-zA-Z0-9]+)?:[0-9]+:.*$' "$CMD_ARGS_FILE" | cut -d: -f1 | tr '\n' ' ')"
    expected_args="$(grep -P '^[a-zA-Z_][a-zA-Z0-9_-]*:true::::.*$' "$CMD_ARGS_FILE" | cut -d: -f1 | tr '\n' ' ')"

    remaining_args=()
    unexpected_args=()
    for ((i=0; i<${#passed_args[@]}; i++)) ; do
        arg="${passed_args[$i]}"
        case "$arg" in
            '-'*|'--'*)
                if ! record=$(grep -P ":${arg}:" "$CMD_ARGS_FILE") ; then
                    if [[ "${#remaining_args[@]}" == '0' ]] ; then 
                        unexpected_args+=("$arg")
                    else
                        remaining_args+=("$arg")
                    fi
                    continue
                fi

                varname="$(echo "$record" | cut -d: -f1)"
                nargs="$(echo "$record" | cut -d: -f5)"
                
                if [[ -n "$varname" ]] ; then
                    expected_flags="$(echo "$expected_flags" | tr ' ' '\n' | grep -v -e "$varname" | tr '\n' ' ')"
                fi

                # num args
                case "$nargs" in
                    '0') eval "${varname}='${arg}'" ;;
                    *)
                        eval "${varname}=()"
                        for _ in $(seq "$nargs") ; do
                            i=$((i + 1))
                            eval "${varname}+=('${passed_args[$((i))]}')"
                        done
                esac
                ;;
            *) 
                if [[ "$seen_positional" == "$positional_count" ]] ; then
                    remaining_args+=("$arg")
                else
                    seen_positional=$((seen_positional + 1))
                    varname="$(grep -m$seen_positional -P '^[a-zA-Z_][a-zA-Z0-9_-]*:(true|false)::::.*$' "$CMD_ARGS_FILE" | tail -n1 | cut -d: -f1)"
                    eval "${varname}='${arg}'"
                    expected_args="$(echo "$expected_args" | tr ' ' '\n' | grep -v -e "$varname" | tr '\n' ' ')"
                fi
                ;;
        esac
    done

    if [[ "${#unexpected_args}" != '0' ]] || [[ -n "$(echo "$expected_flags" | tr -d ' ')" ]] ; then
        return 1
    fi

    return 0
}

print_args_errors() {
    if [[ -z "$CMD_ARGS_FILE" ]] ; then
        2>&1 echo "\$CMD_ARGS_FILE was expected to contain the path of a .args file"
        return 1
    fi

    if [[ ! -f "$CMD_ARGS_FILE" ]] ; then
        2>&1 echo "\$CMD_ARGS_FILE does not contain a valid path to an .args file"
        return 1
    fi

    if ! validate_args_file "$CMD_ARGS_FILE" ; then
        2>&1 echo -e "\nArgs file validation failed"
        return 1
    fi

    if [[ "${#unexpected_args}" != '0' ]] ; then
        2>&1 echo -n 'Unexpected arguments: '
        for arg in "${unexpected_args[@]}" ; do
            echo -n "${arg} "
        done
        
        echo -e "\n"
        usage
    
        return 1
    fi

    has_prefix='false'
    if [[ -n "$(echo "$expected_flags" | tr -d ' ')" ]] ; then
        2>&1 echo -n 'Expected arguments: '
        has_prefix='true'
        for arg in $expected_flags ; do
            rc=$(grep -P "^${arg}:" "$CMD_ARGS_FILE")
            short=$(echo "$rc" | cut -d: -f3)
            long=$(echo "$rc" | cut -d: -f4)

            if [[ -z "$short" ]] && [[ -z "$long" ]] ; then
                2>&1 echo -n "${arg} "
            elif [[ -n "$short" ]] && [[ -z "$long" ]] ; then
                2>&1 echo -n "${short} "
            elif [[ -z "$short" ]] && [[ -n "$long" ]] ; then
                2>&1 echo -n "${long} "
            elif [[ -n "$short" ]] && [[ -n "$long" ]] ; then
                2>&1 echo -n "${short}/${long} "
            fi
        done

        2>&1 echo -e "\n"
        usage

        return 1
    fi

    if [[ -n "$(echo "$expected_args" | tr -d ' ')" ]] ; then
        if ! $has_prefix ; then
            2>&1 echo -n 'Expected arguments: '
        fi
        echo "$expected_args"

        echo -e "\n"
        usage

        return 1
    fi
}

print_child_commands() {
    cmds="$(ls -1 ${CMD_CHILD_DIR}/*.sh | sed 's#.*/##')"
    if [[ -n "$cmds" ]] ; then
        echo -e "\nAvaiable Commands:"
        for cmd in "$cmds" ; do
            echo "  ${cmd%.sh}"
        done
    fi
}

find_child_command() {
    if [[ -f "${CLI_SH_CMD}/${command}.sh" ]] ; then
        echo "${CLI_SH_CMD}/${command}.sh"
        return 0
    fi

    return 1
}