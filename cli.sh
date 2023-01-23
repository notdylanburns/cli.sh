#!/bin/bash

arg_name_re='([a-zA-Z_-][a-zA-Z0-9_-]*)'
required_re='(true|false)'
short_flag_re='(-[a-zA-Z0-9])'
long_flag_re='(--[a-zA-Z0-9-]+)'
arg_count_re='([0-9]+)'
description_re='(.*)'
short_or_long_flag_re="((${short_flag_re}:)|(:${long_flag_re})|(${short_flag_re}:${long_flag_re}))"
positional_arg_re="^${arg_name_re}:${required_re}::::${description_re}$"
required_positional_re="^${arg_name_re}:true::::${description_re}$"
flag_arg_re="^${arg_name_re}:${required_re}:${short_or_long_flag_re}:${arg_count_re}:${description_re}$"
required_flag_re="^${arg_name_re}:true:${short_or_long_flag_re}:${arg_count_re}:${description_re}$"
valid_argument_re="(${positional_arg_re})|($flag_arg_re)"

arg_name_pos='1'
required_pos='2'
short_flag_pos='3'
long_flag_pos='4'
arg_count_pos='5'
description_pos='6'

import() {
    source "${CLI_SH_LIB}/${1}.rc"
}

debug() {
    echo $@
}

extract_arg_field() {
    record="$1"
    field="$2"

    echo "$record" | cut -d':' -f$field
}

validate_args_file() {
    if [[ -z "$CMD_ARGS_FILE" ]] ; then
        2>&1 echo "\$CMD_ARGS_FILE was expected to contain the path of a .args file"
        return 1
    fi

    if [[ ! -f "$CMD_ARGS_FILE" ]] ; then
        2>&1 echo "\$CMD_ARGS_FILE does not contain a valid path to an .args file"
        return 1
    fi

    if errors=$(grep -HnPv "$valid_argument_re" "$CMD_ARGS_FILE") ; then
        2>&1 echo -e "\e[1;31merror:\e[0m invalid args file '${CMD_ARGS_FILE}'\n"

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
        2>&1 echo -e "\nargs file validation failed"
        return 1
    fi

    echo -n "usage: $CMD_CALLED_AS "

    longest=0

    has_flags='false'
    if flag_args="$(grep -P "$flag_arg_re" "$CMD_ARGS_FILE")" ; then
        flag_args=$(echo "$flag_args"  | sort -t':' -k${long_flag_pos})
        echo -n '[flags] '
        has_flags='true'

        while read -r arg ; do
            long_len=$(extract_arg_field "$arg" "$long_flag_pos" | wc -m)
            if [[ "$long_len" -gt "$longest" ]] ; then
                longest="$long_len"
            fi
        done <<< "$flag_args"

    fi

    has_global_flags='false'
    global_flag_args="$(printf "%s\n%s" "$GLOBAL_FLAGS" "$flag_args" | sort -t':' -k${long_flag_pos} | uniq -u)"
    if [[ -n "$(echo -n $global_flag_args)" ]]; then
        if ! $has_flags ; then
            echo -n '[flags] '
        fi

        has_global_flags='true'

        while read -r arg ; do
            long_len=$(extract_arg_field "$arg" "$long_flag_pos" | wc -m)
            if [[ "$long_len" -gt "$longest" ]] ; then
                longest="$long_len"
            fi
        done <<< "$global_flag_args"

    fi

    if positional_args="$(grep -P "${positional_arg_re}" "$CMD_ARGS_FILE")" ; then
        while read -r arg ; do
            name=$(extract_arg_field "$arg" "$arg_name_pos")
            if [[ "$(extract_arg_field "$arg" "$required_pos")" == 'true' ]] ; then
                echo -n "<${name}> "
            else
                echo -n "[${name}] "
            fi

            if [[ "${#name}" -gt "$longest" ]] ; then
                longest="${#name}"
            fi
        done <<< "$positional_args"
        echo

        echo -e '\npositional arguments:'

        while read -r arg ; do
            name=$(extract_arg_field "$arg" "$arg_name_pos")
            short_desc=$(extract_arg_field "$arg" "$description_pos")
            printf "  %-*s%s" "$((longest + 8))" "$name" "$short_desc"

            if [[ "$(extract_arg_field "$arg" "$required_pos")" == 'true' ]] ; then
                echo -n " (required)"
            fi

            echo
        done <<< "$positional_args"

    fi

    if $has_flags ; then
        echo -e '\nflags:'
        while read -r arg; do
            short_form=$(extract_arg_field "$arg" "$short_flag_pos")
            long_form=$(extract_arg_field "$arg" "$long_flag_pos")
            short_desc=$(extract_arg_field "$arg" "$description_pos")
            if [[ -z "$short_form" ]] ; then
                printf "       %-*s%s" "$((longest + 3))" "$long_form" "$short_desc"
            else
                printf "  %s,  %-*s%s" "$short_form" "$((longest + 3))" "$long_form" "$short_desc"
            fi
            if [[ "$(extract_arg_field "$arg" "$required_pos")" == 'true' ]] ; then
                echo -n " (required)"
            fi

            echo
        done <<< "$flag_args"
    fi

    if $has_global_flags ; then
        echo -e '\nglobal flags:'
        while read -r arg; do
            short_form=$(extract_arg_field "$arg" "$short_flag_pos")
            long_form=$(extract_arg_field "$arg" "$long_flag_pos")
            short_desc=$(extract_arg_field "$arg" "$description_pos")
            if [[ -z "$short_form" ]] ; then
                printf "       %-*s%s" "$((longest + 3))" "$long_form" "$short_desc"
            else
                printf "  %s,  %-*s%s" "$short_form" "$((longest + 3))" "$long_form" "$short_desc"
            fi
            if [[ "$(extract_arg_field "$arg" "$required_pos")" == 'true' ]] ; then
                echo -n " (required)"
            fi

            echo
        done <<< "$global_flag_args"
    fi
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
        2>&1 echo -e "\nerror: args file validation failed"
        return 1
    fi

    passed_args=("$@")

    if all_flags=$(grep -P "$flag_arg_re" "$CMD_ARGS_FILE") ; then
        if [[ -z "$GLOBAL_FLAGS" ]] ; then
            export GLOBAL_FLAGS="$all_flags"
        else
            export GLOBAL_FLAGS=$(printf '%s\n%s' "$GLOBAL_FLAGS" "$all_flags")
        fi
    fi

    positional_count="$(grep -P "$positional_arg_re" "$CMD_ARGS_FILE" | wc -l)"
    seen_positional=0

    expected_flags="$(grep -P "$required_flag_re" "$CMD_ARGS_FILE" | cut -d: -f${arg_name_pos} | tr '\n' ' ')"
    expected_args="$(grep -P "$required_positional_re" "$CMD_ARGS_FILE" | cut -d: -f${arg_name_pos} | tr '\n' ' ')"

    remaining_args=()
    unexpected_args=()
    all_positional='false'
    for ((i=0; i<${#passed_args[@]}; i++)) ; do
        arg="${passed_args[$i]}"
        if [[ "$arg" == '--' ]] && ! $all_positional ; then
            all_positional='true'
            continue
        fi

        if ! $all_positional ; then
            case "$arg" in
                '-'*|'--'*)
                    if ! record=$(grep -P ":${arg}:" "$CMD_ARGS_FILE") ; then
                        if [[ "${#remaining_args[@]}" == '0' ]] && [[ "$seen_positional" == '0' ]] ; then
                            unexpected_args+=("$arg")
                        else
                            remaining_args+=("$arg")
                        fi
                        continue
                    fi

                    varname="$(extract_arg_field "$record" "$arg_name_pos")"
                    varname_san=$(echo "$varname" | tr '-' '_')
                    nargs="$(extract_arg_field "$record" "$arg_count_pos")"

                    if [[ -n "$varname" ]] ; then
                        expected_flags="$(echo "$expected_flags" | tr ' ' '\n' | grep -v -e "$varname" | tr '\n' ' ')"
                    fi

                    # num args
                    case "$nargs" in
                        '0') eval "export ${varname_san}='${arg}'" ;;
                        *)
                            eval "export ${varname_san}=()"
                            for _ in $(seq "$nargs") ; do
                                i=$((i + 1))
                                eval "export ${varname_san}+=('${passed_args[$i]}')"
                            done
                    esac
                    ;;
                *)
                    if [[ "$postional_count" == '0' ]] ; then
                        unexpected_args+=("$arg")
                    elif [[ "$seen_positional" == "$positional_count" ]] ; then
                        remaining_args+=("$arg")
                    else
                        seen_positional=$((seen_positional + 1))
                        varname="$(grep -m$seen_positional -P "$positional_arg_re" "$CMD_ARGS_FILE" | tail -n1 | cut -d: -f${arg_name_pos})"
                        varname_san=$(echo "$varname" | tr '-' '_')
                        eval "export ${varname_san}='${arg}'"
                        expected_args="$(echo "$expected_args" | tr ' ' '\n' | grep -v -e "$varname" | tr '\n' ' ')"
                    fi
                    ;;
            esac
        else
            if [[ "$postional_count" == '0' ]] ; then
                unexpected_args+=("$arg")
            elif [[ "$seen_positional" == "$positional_count" ]] ; then
                remaining_args+=("$arg")
            else
                seen_positional=$((seen_positional + 1))
                varname="$(grep -m$seen_positional -P "$positional_arg_re" "$CMD_ARGS_FILE" | tail -n1 | cut -d: -f${arg_name_pos})"
                varname_san=$(echo "$varname" | tr '-' '_')
                eval "export ${varname_san}='${arg}'"
                expected_args="$(echo "$expected_args" | tr ' ' '\n' | grep -v -e "$varname" | tr '\n' ' ')"
            fi
        fi
    done

    if [[ "${#unexpected_args[@]}" != '0' ]] || [[ -n "$(echo "$expected_flags" | tr -d ' ')" ]] || [[ -n "$(echo "$expected_args" | tr -d ' ')" ]] ; then
        return 1
    fi

    return 0
}

print_args_errors() {
    if [[ "${#unexpected_args}" != '0' ]] ; then
        2>&1 echo -n 'unexpected arguments: '
        for arg in "${unexpected_args[@]}" ; do
            echo -n "${arg} "
        done

        echo -e "\n"
        2>&1 usage

        return 1
    fi

    has_prefix='false'
    if [[ -n "$(echo "$expected_flags" | tr -d ' ')" ]] ; then
        2>&1 echo -n 'expected arguments: '
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
            2>&1 echo -n 'expected arguments: '
        fi
        2>&1 echo "$expected_args"

        2>&1 echo

        2>&1 usage

        return 1
    fi
}

print_child_commands() {
    cmds=$(find "${CMD_CHILD_DIR}" -maxdepth 1 -name '*.sh' -exec basename {} ';')
    if [[ -n "$cmds" ]] ; then
        echo -e "avaiable commands:"
        for cmd in $cmds ; do
            echo "  ${cmd%.sh}"
        done
    fi
}

find_child_command() {
    if [[ -f "${CMD_CHILD_DIR}/${!CMD_SUBCOMMAND_VAR}.sh" ]] ; then
        echo "${CMD_CHILD_DIR}/${!CMD_SUBCOMMAND_VAR}.sh"
        return 0
    fi

    return 1
}