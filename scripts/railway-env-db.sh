#!/bin/sh
# Construye DATABASE_URL si Railway inyectó PGHOST/PGUSER/etc.
if [ -z "$DATABASE_URL" ] && [ -n "$PGHOST" ]; then
  export DATABASE_URL="postgresql://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}"
  echo "==> DATABASE_URL generada desde PGHOST=${PGHOST}"
fi

if [ -z "$DATABASE_URL" ]; then
  echo "ERROR: Sin conexion a Postgres."
  echo "En agenda_de-_trabajo → Variables → Raw Editor agrega:"
  echo "  DATABASE_URL=\${{Postgres--CyS.DATABASE_URL}}"
  echo "O usa Connect en Postgres--CyS → agenda_de-_trabajo"
  exit 1
fi

export DB_CONNECTION=pgsql
