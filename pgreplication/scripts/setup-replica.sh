#!/usr/bin/env bash

set -e
set -o pipefail


_msg()
{
    echo -e "$*" >&2
}

run_replica_setup()
{
    if [[ -n "$DEBUG" ]] ; then
        set -x
    fi

    local -r pgpass_file="${HOME}/.pgpass"

    if [[ -s "$PGDATA/PG_VERSION" ]] ; then
        _msg "Postgres data directory '$PGDATA' already exists; skipping replica setup"
        return 0
    fi

    _msg "Trying connection to primary host $PG_PRIMARY_HOST"

    until ping -c 1 -W 2 "$PG_PRIMARY_HOST" ; do
        echo "Waiting for primary to ping..." >&2
        sleep 1
    done

    _msg "Creating pgpass file '$pgpass_file'"

    echo "*:*:*:${REPLICATION_USER}:${REPLICATION_PASSWORD}" > "$pgpass_file"
    chmod -v 600 "$pgpass_file"

    _msg "Running pg_basebackup"

    until pg_basebackup \
        -h "$PG_PRIMARY_HOST" -U "$REPLICATION_USER" -D "$PGDATA" \
        --wal-method fetch \
        --write-recovery-conf \
        --progress \
        --verbose
    do
        echo "Waiting for primary..." >&2
        sleep 1
    done

    _msg "Removing pgpass file"

    rm -fv "${HOME}/.pgpass"

    _msg "Creating file 'postgresql.auto.conf'"

    cat <<EOF > "${PGDATA}/postgresql.auto.conf"
primary_conninfo = 'host=$PG_PRIMARY_HOST port=${PG_PRIMARY_PORT:-5432} user=$REPLICATION_USER password=$REPLICATION_PASSWORD'
EOF

    _msg "Ensuring correct permissions on data directoy '$PGDATA'"

    chown -R postgres:postgres "$PGDATA"
    chmod -R go= "$PGDATA"

    if [[ -n "$WAIT_FOREVER" ]] ; then
        _msg "Variable WAIT_FOREVER is defined, sleeping forever!"

        while true ; do
            _msg "Sleeping..."
            sleep 30
        done
    fi

    _msg "Replica setup successfully finished!"
}


case $1 in
    run-setup)
        shift
        run_replica_setup
    ;;
esac


exec /usr/local/bin/docker-entrypoint.sh postgres "$@"
