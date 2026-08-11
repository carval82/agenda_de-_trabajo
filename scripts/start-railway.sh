#!/bin/sh
set -e

echo "==> Railway startup..."

if [ -z "$DATABASE_URL" ]; then
  echo "ERROR: DATABASE_URL no está configurada."
  echo "En Railway: Postgres → Connect → vincula al servicio web"
  echo "O agrega en Variables: DATABASE_URL=\${{Postgres.DATABASE_URL}}"
  exit 1
fi

export DB_CONNECTION=pgsql

echo "==> Limpiando cache de configuración..."
php artisan config:clear
php artisan route:clear
php artisan view:clear

echo "==> Ejecutando migraciones en PostgreSQL..."
php artisan migrate --force --no-interaction

echo "==> Seed de datos iniciales..."
php artisan db:seed --force --no-interaction

echo "==> Optimizando Laravel..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

echo "==> Iniciando servidor en puerto ${PORT:-8080}..."
exec php artisan serve --host=0.0.0.0 --port="${PORT:-8080}"
