#!/bin/bash

############# Global #############

G_ENV_PATH=`cd $(dirname $BASH_SOURCE)/..; pwd`
G_ENV_NAME=
G_ENV_FILE=$G_ENV_PATH/output/.env

############# Function #############

function usage
{
    echo "Usage: source $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help                  Show this help message and exit"
    echo "  -n, --name  <venv name>     Set the name of the virtual environment (default: ${G_ENV_NAME})"
}

function deactivate
{
    if ! [ -z "${_OLD_VIRTUAL_PATH:+_}" ] ; then
        PATH="$_OLD_VIRTUAL_PATH"
        export PATH
        unset _OLD_VIRTUAL_PATH
    fi

    hash -r 2>/dev/null

    if ! [ -z "${_OLD_VIRTUAL_PS1+_}" ] ; then
        PS1="$_OLD_VIRTUAL_PS1"
        export PS1
        unset _OLD_VIRTUAL_PS1
    fi

    unset VIRTUAL_ENV
    unset VIRTUAL_ENV_PROMPT

    # unset all CERTM_* variables
    if env |grep -q CERTM_
    then
        unset $(env |grep CERTM_ | cut -d '=' -f 1)
    fi

    # unset all certm-* alias
    if alias -p | grep -q certm-
    then
        unalias $(alias -p |grep certm- | cut -d ' ' -f 2 | cut -d '=' -f 1)
    fi

    if [ ! "${1-}" = "nondestructive" ] ; then
        unset -f deactivate
    fi
}

############ Main ############

# set default name of venv

if [ -f $G_ENV_PATH/output/.venv_name ]; then
    G_ENV_NAME=$(cat $G_ENV_PATH/output/.venv_name)
fi

if [ -z "$G_ENV_NAME" ]; then
    G_ENV_NAME=$(basename $G_ENV_PATH)
fi

# Parse arguments

opt_help=
opt_name=

while [ $# -gt 0 ]
do
    case "$1" in
        -h|--help)
            opt_help=1
            ;;
        -n|--name)
            opt_name="$2"
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
    shift
done

if [ -n "$opt_help" ]; then
    usage
    exit 0
fi

if [ -n "$opt_name" ]; then
    G_ENV_NAME="$opt_name"
fi

if [ "${BASH_SOURCE}" = "$0" ]; then
    echo "You must source this script: \$ source $0" >&2
    exit 33
fi

# unset irrelevant variables

deactivate nondestructive

# save virtual environment name

echo "$G_ENV_NAME" > $G_ENV_PATH/output/.venv_name

# apply environment file
[ -f $G_ENV_FILE ] && source $G_ENV_FILE

VIRTUAL_ENV=G_ENV_PATH/
export VIRTUAL_ENV

_OLD_VIRTUAL_PATH="$PATH"
PATH="$VIRTUAL_ENV/src/tools:$PATH"
export PATH

VIRTUAL_ENV_PROMPT=$G_ENV_NAME
export VIRTUAL_ENV_PROMPT

_OLD_VIRTUAL_PS1="${PS1-}"
PS1="(${VIRTUAL_ENV_PROMPT}) ${PS1-}"
export PS1

hash -r 2>/dev/null