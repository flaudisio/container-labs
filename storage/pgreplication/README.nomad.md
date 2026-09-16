# Postgres replication on Nomad

Goal: run the same [Docker Compose stack](README.md) on Nomad.

## Requirements

You'll need a running Nomad cluster integrated to Consul.

## Preparing

Create the `.env` file:

```console
$ cp .env.example .env
```

## Testing the replication

Create the job:

```console
$ nomad job run pgreplication.nomad
```

Get the allocation IDs:

```console
$ nomad alloc status -json | jq -r '.[] | select(.JobID == "pgreplication" and .ClientStatus == "running") | .TaskGroup + " - " + .ID'
primary - cb23eb51-5eb8-0365-c84a-88002c38e2fa
replica-01 - 9d6fd171-f691-3ed4-1ee7-5826749344c1
```

Check the replication status on **primary**:

```console
$ nomad alloc exec cb23eb51 psql -U postgres -c 'SELECT * FROM pg_stat_replication;'
 pid | usesysid |  usename   | application_name |  client_addr  | client_hostname | client_port |         backend_start         | backend_xmin |   state   | sent_lsn  | write_lsn | flush_lsn | replay_lsn | write_lag | flush_lag | replay_lag | sync_priority | sync_state |          reply_time
-----+----------+------------+------------------+---------------+-----------------+-------------+-------------------------------+--------------+-----------+-----------+-----------+-----------+------------+-----------+-----------+------------+---------------+------------+-------------------------------
 315 |    16384 | replicator | walreceiver      | 10.110.35.111 |                 |       42192 | 2023-08-10 22:12:20.848541+00 |              | streaming | 0/3000148 | 0/3000148 | 0/3000148 | 0/3000148  |           |           |            |             0 | async      | 2023-08-10 22:26:04.199464+00
(1 row)
```

Check the WAL receiver status on **replica**:

```console
$ nomad alloc exec 9d6fd171 psql -U postgres -c 'SELECT * FROM pg_stat_wal_receiver;'
 pid |  status   | receive_start_lsn | receive_start_tli | written_lsn | flushed_lsn | received_tli |      last_msg_send_time       |     last_msg_receipt_time     | latest_end_lsn |        latest_end_time        | slot_name | sender_host  | sender_port |                                                                                                                                        conninfo
-----+-----------+-------------------+-------------------+-------------+-------------+--------------+-------------------------------+-------------------------------+----------------+-------------------------------+-----------+--------------+-------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  39 | streaming | 0/3000000         |                 1 | 0/3000148   | 0/3000148   |            1 | 2023-08-10 22:26:24.151897+00 | 2023-08-10 22:26:24.152173+00 | 0/3000148      | 2023-08-10 22:17:23.234366+00 |           | 10.110.28.24 |       20535 | user=replicator password=******** channel_binding=prefer dbname=replication host=10.110.28.24 port=20535 fallback_application_name=walreceiver sslmode=prefer sslcompression=0 sslsni=1 ssl_min_protocol_version=TLSv1.2 gssencmode=prefer krbsrvname=postgres target_session_attrs=any
(1 row)

$ nomad alloc exec 9d6fd171 psql -U postgres -c 'SELECT pg_is_in_recovery();'
 pg_is_in_recovery
-------------------
 t
(1 row)
```

Create a database on **primary**:

```console
$ nomad alloc exec cb23eb51 psql -U postgres -c 'CREATE DATABASE example1;'
CREATE DATABASE
```

Check if database exists on **replica**:

```console
$ nomad alloc exec 9d6fd171 psql -U postgres -c '\l example1'
                              List of databases
   Name   |  Owner   | Encoding |  Collate   |   Ctype    | Access privileges
----------+----------+----------+------------+------------+-------------------
 example1 | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
(1 row)
```

Try to create a database on **replica**:

```console
$ nomad alloc exec 9d6fd171 psql -U postgres -c 'CREATE DATABASE example2;'
ERROR:  cannot execute CREATE DATABASE in a read-only transaction
```

To create extra replicas, copy the `group "replica-01" {}` block in the job file and change it accordingly.
