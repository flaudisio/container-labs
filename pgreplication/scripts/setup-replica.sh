#!/usr/bin/env bash

set -e
set -o pipefail

: "${PG_PRIMARY_PORT:="5432"}"


_msg()
{
    echo -e "$*" >&2
}

check_env()
{
    if [[ -n "$PG_PRIMARY_HOST"  ]] ; then
        return 0
    fi

    _msg "Error: the PG_PRIMARY_HOST variable is not defined"

    if [[ -n "$ENV_CHECK_WAIT" ]] ; then
        _msg "Sleeping for ${ENV_CHECK_WAIT}s before aborting"
        sleep "$ENV_CHECK_WAIT"
    fi

    exit 2
}

wait_for_primary_host()
{
    local -r retries=10
    local count=1

    while [[ $count -le $retries ]] ; do
        _msg "Trying to connect to primary host on '${PG_PRIMARY_HOST}:${PG_PRIMARY_PORT}' ($count/$retries)"

        if nc -vzw 2 "$PG_PRIMARY_HOST" "$PG_PRIMARY_PORT" ; then
            _msg "Successfully connected"
            return 0
        fi

        (( count++ ))
        sleep 1
    done

    _msg "Error: could not connect to primary host; aborting"
    exit 1
}

run_replica_setup()
{
    if [[ -n "$DEBUG" ]] ; then
        set -x
    fi

    local -r pgpass_file="${HOME}/.pgpass"

    if [[ -s "${PGDATA}/PG_VERSION" ]] ; then
        _msg "Postgres data directory '$PGDATA' already exists; skipping replica setup"
        return 0
    fi

    _msg "Creating pgpass file '$pgpass_file'"

    echo "*:*:*:${REPLICATION_USER}:${REPLICATION_PASSWORD}" > "$pgpass_file"
    chmod -v 600 "$pgpass_file"

    _msg "Running pg_basebackup"

    if ! pg_basebackup \
        -h "$PG_PRIMARY_HOST" -p "$PG_PRIMARY_PORT" -U "$REPLICATION_USER" -D "$PGDATA" \
        --wal-method fetch \
        --write-recovery-conf \
        --progress \
        --verbose
    then
        _msg "Error running pg_basebackup; aborting"
        exit 1
    fi

    _msg "Removing pgpass file"

    rm -fv "$pgpass_file"

    _msg "Creating file 'postgresql.auto.conf'"

    cat <<EOF > "${PGDATA}/postgresql.auto.conf"
primary_conninfo = 'host=$PG_PRIMARY_HOST port=$PG_PRIMARY_PORT user=$REPLICATION_USER password=$REPLICATION_PASSWORD'
EOF

    _msg "Ensuring correct permissions on data directoy '$PGDATA'"

    chown -R postgres:postgres "$PGDATA"
    chmod -R go= "$PGDATA"

    if [[ -n "$SETUP_WAIT_FOREVER" ]] ; then
        _msg "Variable SETUP_WAIT_FOREVER is defined, sleeping forever!"

        while true ; do
            _msg "Sleeping..."
            sleep 30
        done
    fi

    _msg "Replica setup successfully finished!"
}


case $1 in
    wait-primary)
        check_env
        wait_for_primary_host
    ;;

    run-setup)
        shift
        check_env
        wait_for_primary_host
        run_replica_setup
    ;;
esac


exec /usr/local/bin/docker-entrypoint.sh postgres "$@"
