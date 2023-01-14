#!/bin/bash

usage() {
    2>&1 echo -e "Usage: $0 <cli-name>\n"
    2>&1 echo "    cli-name     the name of this cli.sh project"
}

cli_libpath="$(dirname $(realpath $0))"

cli_name="$1"
path="$(pwd)"

if [[ "$#" != 1 ]] ; then
    usage
    exit 1
fi

if [[ ! "$cli_name" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]] ; then
    2>&1 echo "Invalid value for parameter cli-name. Names must start with a letter / underscore, and can contain letters, numbers, hyphens and underscores only."
    exit 1
fi

if [[ -z "$path" ]] || [[ ! -d "$path" ]] ; then
    2>&1 echo "Invalid value for parameter directory."
    exit 1
fi

var_cli_name=$(echo "${cli_name^^}" | tr '-' '_')
fullpath=$(realpath "$path")

echo -e "\e[1;32mCreating cmd dir at \e[36m${fullpath}/cmd\e[32m...\e[0m"
if ! mkdir -p "${fullpath}/cmd" ; then
    exit 1
fi

echo -e "\e[1;32mGenerating ${cli_name}.rc file at filepath \e[36m${fullpath}/${cli_name}.rc\e[32m...\e[0m\n"

if ! tee "${fullpath}/${cli_name}.rc" ; then
    exit 1
fi << EOF
export CLI_SH_ROOT_NAME='${var_cli_name}'
export ${var_cli_name}_ROOT="${fullpath}"
export ${var_cli_name}_CMD="${fullpath}/cmd"
EOF

echo -e "\n"

echo -e "\e[1;32mGenerating ${cli_name}.args file at filepath \e[36m${fullpath}/${cli_name}.args\e[32m...\e[0m\n"

if ! tee "${fullpath}/${cli_name}.args" ; then
    exit 1
fi << EOF
help:false:-h:--help:0:show help for this command
EOF

echo -e "\n"

echo -e "\e[1;32mGenerating entry point file ${cli_name} at filepath \e[36m${fullpath}/${cli_name}\e[32m...\e[0m\n"

if ! tee "${fullpath}/${cli_name}" ; then
    exit 1
fi << EOF
#!/bin/bash

source "${cli_libpath}/cli.sh"
source "\$(dirname \$(realpath \$0))/${cli_name}.rc"

export CMD_ARGS_FILE="\$0.args"
export CMD_CALLED_AS="\$0"

help() {
    echo "${cli_name}: your description here"
    echo

    usage

    cmds="\$(ls -w1 \$TEST_CLI_CMD)"
    if [[ "\$(echo -n "\$cmds" | wc -l)" != '0' ]]; then
        echo -e "\nAvaiable Commands:"
        for cmd in "\$cmds" ; do
            echo "  \$cmd"
        done
    fi
}

main() {
    if [[ -n "\$help" ]] ; then
        help
        exit 0
    elif ! (exit \$args_valid) ; then
        print_args_errors
        exit 1
    fi

    echo "Running ${cli_name}"
}

parse_args \$@
args_valid="\$?"

main
EOF

echo -e "\n"

echo -e "\e[1;32mMaking entry point file at filepath \e[36m${fullpath}/${cli_name}\e[32m executable...\e[0m\n"
if ! chmod +x "${fullpath}/${cli_name}" ; then
    exit 1
fi