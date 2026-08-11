#!/bin/sh
set -e

echo "==> Optimizando Laravel para producción..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

echo "==> Ejecutando migraciones..."
php artisan migrate --force

echo "==> Iniciando servidor en puerto ${PORT:-8080}..."
exec php artisan serve --host=0.0.0.0 --port="${PORT:-8080}"
