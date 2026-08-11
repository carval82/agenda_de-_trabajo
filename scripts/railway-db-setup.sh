#!/bin/sh
set -e

. "$(dirname "$0")/railway-env-db.sh"

echo "==> Preparando base de datos PostgreSQL..."
php artisan config:clear

echo "==> Host: ${PGHOST:-desde DATABASE_URL}"
php artisan migrate --force --no-interaction -v

echo "==> Tablas creadas:"
php artisan db:show 2>/dev/null || php artisan migrate:status

echo "==> Seed..."
php artisan db:seed --force --no-interaction

echo "==> Base de datos lista."
