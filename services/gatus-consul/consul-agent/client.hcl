datacenter = "dc1"
domain     = "consul"

data_dir  = "/var/opt/consul"
log_level = "INFO"

disable_update_check = true

bind_addr   = "0.0.0.0"
client_addr = "127.0.0.1"

retry_join = [
  "consul-server",
]

retry_max      = 3
retry_interval = "15s"
