#!/bin/sh
# shellcheck shell=ash

: "${CONTAINER_NAME:=""}"
: "${ERROR_REGEX:="level=error"}"
: "${INTERVAL:="10"}"

_msg()
{
    echo "[$( date )] $*" >&2
}

cleanup()
{
    _msg "Signal received! Exiting cleanly..."
    exit 0
}

main()
{
    trap cleanup INT TERM

    _msg "--------------------------------------------------------"
    _msg "Starting autoheal from inside container..."
    _msg "Monitoring target container '$CONTAINER_NAME'"
    _msg "Checking every $INTERVAL seconds for regex: '$ERROR_REGEX'"
    _msg "--------------------------------------------------------"

    while true ; do
        if [ "$( docker container inspect -f '{{ .State.Running }}' "$CONTAINER_NAME" 2> /dev/null)" != "true" ] ; then
            _msg "WARNING: container '$CONTAINER_NAME' is not running. Retrying in ${INTERVAL}s..."
            sleep "$INTERVAL"
            continue
        fi

        _msg "Checking..."

        if ! docker container logs --tail 5 "$CONTAINER_NAME" 2>&1 | grep -q "$ERROR_REGEX" ; then
            # Nothing to do
            sleep "$INTERVAL"
            continue
        fi

        _msg "WARNING: found '$ERROR_REGEX' in recent logs. Restarting container '$CONTAINER_NAME'..."

        if docker container restart --timeout 5 "$CONTAINER_NAME" ; then
            _msg "Container restarted successfully!"
        else
            _msg "ERROR: could not restart container"
        fi

        sleep 30
    done
}

main "$@"
