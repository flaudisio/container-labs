# Postgres replication

Goal: test Postgres streaming replication using Docker containers, preferably without having to build custom images.

See also a very similar deployment [on Nomad](README.nomad.md).

## Preparing

Create the `.env` file:

```console
$ cp .env.example .env
```

## Testing the replication

Start the primary:

```console
$ docker compose up -d primary
```

Start the first replica:

```console
$ docker compose up -d replica-01
```

Check the replication status on **primary**:

```console
$ docker container exec -i -t pgreplication-primary psql -U postgres -c 'SELECT * FROM pg_stat_replication;'
 pid | usesysid |  usename   | application_name |  client_addr  | client_hostname | client_port |         backend_start         | backend_xmin |   state   | sent_lsn  | write_lsn | flush_lsn | replay_lsn | write_lag | flush_lag | replay_lag | sync_priority | sync_state |          reply_time
-----+----------+------------+------------------+---------------+-----------------+-------------+-------------------------------+--------------+-----------+-----------+-----------+-----------+------------+-----------+-----------+------------+---------------+------------+-------------------------------
  80 |    16384 | replicator | walreceiver      | 192.168.199.3 |                 |       59800 | 2023-08-09 13:21:24.570572+00 |              | streaming | 0/3000060 | 0/3000060 | 0/3000060 | 0/3000060  |           |           |            |             0 | async      | 2023-08-09 13:22:22.026913+00
(1 row)
```

Check the WAL receiver status on **replica**:

```console
$ docker container exec -i -t pgreplication-replica-01 psql -U postgres -c 'SELECT * FROM pg_stat_wal_receiver;'
 pid |  status   | receive_start_lsn | receive_start_tli | written_lsn | flushed_lsn | received_tli |      last_msg_send_time       |     last_msg_receipt_time     | latest_end_lsn |        latest_end_time        | slot_name | sender_host | sender_port |                                                                                                                                     conninfo
-----+-----------+-------------------+-------------------+-------------+-------------+--------------+-------------------------------+-------------------------------+----------------+-------------------------------+-----------+-------------+-------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  33 | streaming | 0/3000000         |                 1 | 0/5000060   | 0/5000060   |            1 | 2023-08-09 13:37:04.755958+00 | 2023-08-09 13:37:04.756002+00 | 0/5000060      | 2023-08-09 13:36:34.676619+00 |           | primary     |        5432 | user=replicator password=******** channel_binding=prefer dbname=replication host=primary port=5432 fallback_application_name=walreceiver sslmode=prefer sslcompression=0 sslsni=1 ssl_min_protocol_version=TLSv1.2 gssencmode=prefer krbsrvname=postgres target_session_attrs=any
(1 row)

$ docker container exec -i -t pgreplication-replica-01 psql -U postgres -c 'SELECT pg_is_in_recovery();'
 pg_is_in_recovery
-------------------
 t
(1 row)
```

Create a database on **primary**:

```console
$ docker container exec -i -t pgreplication-primary psql -U postgres -c 'CREATE DATABASE example1;'
CREATE DATABASE
```

Check if database exists on **replica**:

```console
$ docker container exec -i -t pgreplication-replica-01 psql -U postgres -c '\l example1'
                              List of databases
   Name   |  Owner   | Encoding |  Collate   |   Ctype    | Access privileges
----------+----------+----------+------------+------------+-------------------
 example1 | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
(1 row)
```

Try to create a database on **replica**:

```console
$ docker container exec -i -t pgreplication-replica-01 psql -U postgres -c 'CREATE DATABASE example2;'
ERROR:  cannot execute CREATE DATABASE in a read-only transaction
```

Start the second replica:

```console
$ docker compose up -d replica-02
```

Check the replication status on **primary**:

```console
$ docker container exec -i -t pgreplication-primary psql -U postgres -c 'SELECT * FROM pg_stat_replication;'
 pid | usesysid |  usename   | application_name |  client_addr  | client_hostname | client_port |         backend_start         | backend_xmin |   state   | sent_lsn  | write_lsn | flush_lsn | replay_lsn | write_lag | flush_lag | replay_lag | sync_priority | sync_state |          reply_time
-----+----------+------------+------------------+---------------+-----------------+-------------+-------------------------------+--------------+-----------+-----------+-----------+-----------+------------+-----------+-----------+------------+---------------+------------+-------------------------------
  80 |    16384 | replicator | walreceiver      | 192.168.199.3 |                 |       59800 | 2023-08-09 13:21:24.570572+00 |              | streaming | 0/5000060 | 0/5000060 | 0/5000060 | 0/5000060  |           |           |            |             0 | async      | 2023-08-09 13:36:54.931448+00
 191 |    16384 | replicator | walreceiver      | 192.168.199.4 |                 |       51604 | 2023-08-09 13:36:31.726982+00 |              | streaming | 0/5000060 | 0/5000060 | 0/5000060 | 0/5000060  |           |           |            |             0 | async      | 2023-08-09 13:36:54.931488+00
(2 rows)
```

## References

- https://medium.com/swlh/postgresql-replication-with-docker-c6a904becf77
- https://medium.com/@2hamed/replicating-postgres-inside-docker-the-how-to-3244dc2305be
- https://gist.github.com/mattupstate/c6a99f7e03eff86f170e
- https://awstip.com/postgresql-sync-streaming-replication-for-docker-8216e8864de2
- https://stackoverflow.com/questions/43388243/check-postgres-replication-status
- https://www.enterprisedb.com/blog/how-set-streaming-replication-keep-your-postgresql-database-performant-and-date
- https://dbaclass.com/article/how-to-configure-streaming-replication-in-postgres-14/
- https://it-inzhener.com/en/articles/detail/postgresql-simple-replication-setup
