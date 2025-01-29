#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	CREATE USER grafana_user WITH PASSWORD '{{GRAFANA_DB_PASSWORD}}';
	CREATE DATABASE grafana;
	GRANT ALL PRIVILEGES ON DATABASE grafana TO grafana_user;
	ALTER DATABASE grafana OWNER TO grafana_user;
EOSQL