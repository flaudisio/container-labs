#!/bin/sh
# shellcheck shell=ash

: "${CONTAINER_NAME:=""}"
: "${INTERVAL:="10"}"

: "${TRIGGER_TYPE:="logs"}"
: "${CONNS_THRESHOLD:="50"}"
: "${TIMER_INTERVAL:="600"}"
: "${ERROR_REGEX:="level=error"}"

_msg()
{
    echo "$( date ) $*" >&2
}

cleanup()
{
    _msg "Signal received! Exiting cleanly..."
    exit 0
}

check_ansible_running()
{
    local pids

    while true ; do
        # pids="$( pidof ansible ansible-galaxy ansible-playbook )"
        # pids="$( docker container exec "$CONTAINER_NAME" pidof ansible ansible-galaxy ansible-playbook )"
        pids="$( docker container top "$CONTAINER_NAME" -o pid,cmd | grep 'bin/ansible' | awk -v ORS=' ' '{ print $1 }' | sed 's/ $//' )"

        if [ -z "$pids" ] ; then
            _msg "Ansible is not running"
            return 0
        fi

        _msg "Waiting for Ansible to finish (PIDs: ${pids}), will re-check in 10s"
        sleep 10
    done
}

main()
{
    local restart
    local conns

    trap cleanup INT TERM

    _msg "--------------------------------------------------------"
    _msg "Starting autoheal script"
    _msg "Target container: $CONTAINER_NAME"
    _msg "Interval: $INTERVAL seconds"
    _msg "Connections threshold: $CONNS_THRESHOLD"
    _msg "Timer interval: $TIMER_INTERVAL"
    _msg "Error regex: $ERROR_REGEX"
    _msg "--------------------------------------------------------"

    _msg "Check type: $TRIGGER_TYPE"

    while true ; do
        restart=0

        if [ "$( docker container inspect -f '{{ .State.Running }}' "$CONTAINER_NAME" 2> /dev/null)" != "true" ] ; then
            _msg "WARNING: container '$CONTAINER_NAME' is not running. Retrying in ${INTERVAL}s..."
            sleep "$INTERVAL"
            continue
        fi

        if [ "$TRIGGER_TYPE" = "connections" ] ; then
            # _msg "Checking TCP connections"

            # conns="$( docker container run --rm --network="container:${CONTAINER_NAME}" alpine:3.23 netstat -n -t | wc -l )"
            # conns="$( netstat -n -t | wc -l )"
            conns="$( docker container exec "$CONTAINER_NAME" netstat -n -t | wc -l )"

            if [ "$conns" -ge "$CONNS_THRESHOLD" ] ; then
                _msg "WARNING: connections are above threshold (conns: $conns, threshold: $CONNS_THRESHOLD)"
                restart=1
            else
                _msg "Connections are below threshold (conns: $conns, threshold: $CONNS_THRESHOLD)"
            fi
        elif [ "$TRIGGER_TYPE" = "timer" ] ; then
            _msg "Waiting ${TIMER_INTERVAL}s before restarting"
            restart=1
            sleep "$TIMER_INTERVAL"
        else
            # _msg "Checking logs"

            if docker container logs --tail 5 "$CONTAINER_NAME" 2>&1 | grep -q "$ERROR_REGEX" ; then
                _msg "WARNING: found '$ERROR_REGEX' in recent logs"
                restart=1
            else
                _msg "No error logs found"
            fi
        fi

        if [ $restart -eq 0 ] ; then
            sleep "$INTERVAL"
            continue
        fi

        check_ansible_running

        _msg "Restarting container '$CONTAINER_NAME' (timeout: 30s)"

        if docker container restart --timeout 30 "$CONTAINER_NAME" ; then
            _msg "Container restarted successfully!"
        else
            _msg "ERROR: could not restart container"
        fi

        _msg "Waiting 10s before re-evaluation"
        sleep 10
    done
}

main "$@"
