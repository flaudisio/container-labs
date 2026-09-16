# Refs:
# - https://github.com/TwiN/gatus#configuration
# - https://github.com/TwiN/gatus#reloading-configuration-on-the-fly
---
disable-monitoring-lock: true

metrics: true

storage:
  type: sqlite
  path: "${GATUS_DATA_DIR}/gatus.db"

service-endpoint-defaults: &service_defaults
  client:
    timeout: 3s
  interval: 5s
  conditions:
    - "[CONNECTED] == true"

endpoints:
  {{- range services }}
  {{- range service (printf "%v|any" .Name) }}
  {{- if .Tags | contains "gatus"  }}
  - name: {{ .ID }}
    url: tcp://{{ .Address }}:{{ .Port }}
    group: {{ .Name | toTitle }}
    <<: *service_defaults
  {{- end }}
  {{- end }}
  {{- end }}

  - name: Cloudflare DNS
    url: "1.1.1.1"
    group: Internet
    dns:
      query-name: google.com
      query-type: A
    conditions:
      - "[DNS_RCODE] == NOERROR"
  - name: Google DNS
    url: "8.8.8.8"
    group: Internet
    dns:
      query-name: google.com
      query-type: A
    conditions:
      - "[DNS_RCODE] == NOERROR"
