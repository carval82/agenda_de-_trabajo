#!/bin/sh
set -e

. "$(dirname "$0")/railway-env-db.sh"

echo "==> Railway web startup..."

php artisan config:clear
php artisan route:clear
php artisan view:clear

# Migrar por si releaseCommand no corrió
php artisan migrate --force --no-interaction || true
php artisan db:seed --force --no-interaction || true

php artisan config:cache
php artisan route:cache
php artisan view:cache

echo "==> Iniciando scheduler (recordatorios + eventos permanentes)..."
php artisan schedule:work --no-interaction >> storage/logs/scheduler.log 2>&1 &

echo "==> Servidor en puerto ${PORT:-8080}"
exec php artisan serve --host=0.0.0.0 --port="${PORT:-8080}"
