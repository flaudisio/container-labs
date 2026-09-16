# ------------------------------------------------------------------------------
# COMMON CONFIGURATION
# ------------------------------------------------------------------------------

datacenter = "dc1"
domain     = "consul"

data_dir = "/var/opt/consul"
# log_level = "INFO"
log_level = "DEBUG"

disable_update_check = true

bind_addr   = "0.0.0.0"
client_addr = "0.0.0.0"

# ------------------------------------------------------------------------------
# SERVER-ONLY CONFIGURATION
# ------------------------------------------------------------------------------

server    = true
bootstrap = true

server_rejoin_age_max = "4320h"

raft_protocol = 3

autopilot {
  cleanup_dead_servers = true
}

performance {
  raft_multiplier = 1
}

connect {
  enabled = true
}

ui_config {
  enabled = true
}
