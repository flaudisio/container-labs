-- Common:
-- psql -U postgres

-- On primary

SELECT * FROM pg_stat_replication;

CREATE DATABASE temp1;
-- CREATE DATABASE


-- On replicas

SELECT * FROM pg_stat_wal_receiver;

SELECT pg_is_in_recovery();

CREATE DATABASE temp1;
-- ERROR:  cannot execute CREATE DATABASE in a read-only transaction
