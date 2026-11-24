#!/usr/bin/env bash

set -e
set -o pipefail

: "${APP_DIR:="/app"}"

function _msg()
{
    echo "$( date -Iseconds ) [entrypoint] $*" >&2
}

function setup_app_dirs()
{
    local app_dirs=(
        "${APP_DIR}/.cache/ocmonitor"
        "${APP_DIR}/.config/ocmonitor"
    )

    for path in "${app_dirs[@]}" ; do
        if [[ ! -d "$path" ]] ; then
            _msg "Creating $path"
            mkdir -p "$path"
        fi
    done

    for path in "${app_dirs[@]}" ; do
        if ! gosu ocmonitor touch "$path" 2> /dev/null ; then
            _msg "Fixing $path permissions"

            if ! chown -R -h -c "ocmonitor:ocmonitor" -- "$path" ; then
                _msg "Fatal: could not set ownership of $path" >&2
                error=1
            fi
        fi
    done

    [[ $error -eq 0 ]] || exit 1
}

function main()
{
    case "$1" in
        ocmonitor)
            setup_app_dirs
            exec gosu ocmonitor "$@"
        ;;
    esac

    exec "$@"
}


main "$@"
