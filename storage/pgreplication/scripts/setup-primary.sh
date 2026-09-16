#!/usr/bin/env bash

set -e
set -o pipefail


_msg()
{
    echo -e "$*" >&2
}

update_postgres_config()
{
    _msg "Updating file 'pg_hba.conf'"

    echo "host replication all 0.0.0.0/0 scram-sha-256" >> "${PGDATA}/pg_hba.conf"

    _msg "Updating file 'postgresql.conf'"

    cat <<EOF >> "${PGDATA}/postgresql.conf"
wal_level = replica
hot_standby = on
max_wal_senders = 10
max_replication_slots = 10
hot_standby_feedback = on
EOF
}

create_replication_user()
{
    _msg "Creating replication user"

    psql \
        -v ON_ERROR_STOP=1 \
        --username "$POSTGRES_USER" \
        --dbname "$POSTGRES_DATABASE" \
        -c "CREATE USER $REPLICATION_USER WITH REPLICATION ENCRYPTED PASSWORD '$REPLICATION_PASSWORD';"
}

main()
{
    # update_postgres_config
    create_replication_user
}


main "$@"
