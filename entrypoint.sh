#!/bin/sh
exec /bin/icecast_exporter \
  -icecast.scrape-uri="${ICECAST_URL}" \
  -icecast.timeout="${SCRAPE_INTERVAL}" \
  -web.listen-address="${WEB_LISTEN_ADDRESS}" \
  -web.telemetry-path="${WEB_TELEMETRY_PATH}"