// This Nomad job file is designed to be as "equivalent" as possible to the docker-compose.yml file

job "pgreplication" {
  region      = "global"
  datacenters = ["dc1"]

  namespace = "default"
  type      = "service"

  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "10s"
    healthy_deadline  = "10m"
    progress_deadline = "12m"
  }

  group "primary" {
    count = 1

    network {
      port "postgres" {
        to = 5432
      }
    }

    // Use client host volume for persistence
    // volume "postgres-data" {
    //   type      = "host"
    //   source    = "pgreplication-primary-data"
    //   read_only = false
    // }

    task "postgres" {
      service {
        name = "pgreplication-primary"
        port = "postgres"

        check {
          type     = "script"
          task     = "postgres"
          command  = "sh"
          args     = ["-c", "pg_isready -U $POSTGRES_USER"]
          interval = "10s"
          timeout  = "2s"
        }
      }

      driver = "docker"

      config {
        image      = "postgres:14-alpine"
        force_pull = true
        ports      = ["postgres"]

        args = [
          "postgres",
          "-c", "config_file=${NOMAD_TASK_DIR}/postgresql.conf",
          "-c", "hba_file=${NOMAD_TASK_DIR}/pg_hba.conf",
        ]

        volumes = [
          "local/setup-primary.sh:/docker-entrypoint-initdb.d/setup-primary.sh:ro",
        ]
      }

      // Uncomment after configuring the 'postgres-data' volume block above
      // volume_mount {
      //   volume      = "postgres-data"
      //   destination = "/var/lib/postgresql/data"
      // }

      template {
        data        = file("primary/postgresql.conf")
        destination = "${NOMAD_TASK_DIR}/postgresql.conf"
      }

      template {
        data        = file("primary/pg_hba.conf")
        destination = "${NOMAD_TASK_DIR}/pg_hba.conf"
      }

      template {
        data        = file("scripts/setup-primary.sh")
        destination = "${NOMAD_TASK_DIR}/setup-primary.sh"
        perms       = "755"
        change_mode = "noop"
      }

      template {
        data        = file(".env")
        destination = "${NOMAD_SECRETS_DIR}/.env"
        env         = true
      }

      // Use the 'env' block if not interested in the '.env' file
      // env {}

      resources {
        cpu    = 150
        memory = 512
      }
    }
  }

  group "replica-01" {
    count = 1

    network {
      port "postgres" {
        to = 5432
      }
    }

    // Use client host volume for persistence
    // volume "postgres-data" {
    //   type      = "host"
    //   source    = "pgreplication-replica-01-data"
    //   read_only = false
    // }

    task "postgres" {
      service {
        name = "pgreplication-replica-01"
        port = "postgres"

        check {
          type     = "script"
          task     = "postgres"
          command  = "sh"
          args     = ["-c", "pg_isready -U $POSTGRES_USER"]
          interval = "10s"
          timeout  = "2s"
        }
      }

      driver = "docker"

      config {
        image      = "postgres:14-alpine"
        force_pull = true
        ports      = ["postgres"]

        command = "/setup-replica.sh"
        args    = ["run-setup"]

        volumes = [
          "local/setup-replica.sh:/setup-replica.sh:ro",
        ]
      }

      // Uncomment after configuring the 'postgres-data' volume block above
      // volume_mount {
      //   volume      = "postgres-data"
      //   destination = "/var/lib/postgresql/data"
      // }

      template {
        data        = file("scripts/setup-replica.sh")
        destination = "${NOMAD_TASK_DIR}/setup-replica.sh"
        perms       = "755"
        change_mode = "noop"
      }

      template {
        data = <<-EOT
          {{ range service "pgreplication-primary" -}}
          PG_PRIMARY_HOST="{{ .Address }}"
          PG_PRIMARY_PORT="{{ .Port }}"
          {{ end -}}
        EOT

        destination = "${NOMAD_SECRETS_DIR}/.secrets"
        env         = true
      }

      template {
        data        = file(".env")
        destination = "${NOMAD_SECRETS_DIR}/.env"
        env         = true
      }

      env {
        // Wait during environment checks until the primary's Consul service is ready
        // and the 'PG_PRIMARY_*' variables are properly defined
        ENV_CHECK_WAIT = "20"
      }

      resources {
        cpu    = 150
        memory = 256
      }
    }
  }
}
