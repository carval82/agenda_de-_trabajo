# Despliegue en Railway

Guía para publicar la **Agenda de Trabajo** (Laravel + PostgreSQL) en [Railway](https://railway.com).

Repositorio: [github.com/carval82/agenda_de-_trabajo](https://github.com/carval82/agenda_de-_trabajo)

---

## 1. Crear proyecto en Railway

1. Entra a [railway.com](https://railway.com) → **New Project**
2. Elige **Deploy from GitHub repo**
3. Selecciona `carval82/agenda_de-_trabajo`
4. Railway detectará Laravel vía `nixpacks.toml` y `railway.toml`

---

## 2. Agregar PostgreSQL y vincularlo

1. En el proyecto → **+ New** → **Database** → **PostgreSQL**
2. Abre el servicio **Postgres** → pestaña **Connect** (o **Data**)
3. Pulsa **Connect to service** y elige **agenda_de-_trabajo**
   - Esto inyecta `DATABASE_URL` automáticamente en el servicio web
4. Si no aparece Connect, en **Variables** del servicio web agrega manualmente:
   ```env
   DATABASE_URL=${{Postgres.DATABASE_URL}}
   ```
   > Si tu Postgres se llama `Postgres-CyS`, usa: `${{Postgres-CyS.DATABASE_URL}}`

**Sin DATABASE_URL las migraciones corren en SQLite temporal y Postgres queda vacío.**

---

## 3. Variables de entorno (servicio Laravel)

En **Variables** del servicio web, configura:

| Variable | Valor |
|----------|--------|
| `APP_NAME` | `Agenda de Trabajo` |
| `APP_ENV` | `production` |
| `APP_DEBUG` | `false` |
| `APP_KEY` | Genera con `php artisan key:generate --show` en local |
| `APP_URL` | `https://TU-DOMINIO.up.railway.app` |
| `APP_TIMEZONE` | `America/Bogota` |
| `DB_CONNECTION` | `pgsql` |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` o referencia desde Connect |
| `SESSION_DRIVER` | `database` |
| `SESSION_SECURE_COOKIE` | `true` |
| `CACHE_STORE` | `database` |
| `QUEUE_CONNECTION` | `database` |
| `LOG_CHANNEL` | `stderr` |
| `SANCTUM_STATEFUL_DOMAINS` | `TU-DOMINIO.up.railway.app` |

> **APP_KEY:** en local ejecuta `php artisan key:generate --show` y copia el valor.

> **APP_URL:** después del primer deploy, copia la URL pública de Railway (Settings → Networking → Generate Domain).

---

## 4. Primer deploy

Railway ejecutará automáticamente:

```bash
composer install --no-dev
php artisan migrate --force
php artisan serve --host=0.0.0.0 --port=$PORT
```

Healthcheck: `GET /up`

---

## 5. Seed inicial (solo una vez)

Después del primer deploy exitoso, en Railway abre la **consola** del servicio y ejecuta:

```bash
php artisan db:seed --force
```

Esto crea:
- Empresas LC Design e Interveredanet.cr
- Usuario: `pcapacho24@gmail.com`

---

## 6. Recordatorios (cron)

Para avisos estilo PDA en servidor, crea un **Cron Job** en Railway:

| Campo | Valor |
|-------|--------|
| Schedule | `* * * * *` |
| Command | `php artisan schedule:run` |

O un segundo servicio con el mismo repo y start command:

```bash
php artisan schedule:work
```

---

## 7. App Flutter (producción)

En `mobile/agenda_app/lib/config/api_config.dart`, cambia la URL:

```dart
static const String baseUrl = 'https://TU-DOMINIO.up.railway.app/api';
```

Recompila la app:

```bash
cd mobile/agenda_app
flutter build apk
```

---

## 8. Dominio personalizado (opcional)

1. Railway → servicio → **Settings** → **Networking**
2. **Generate Domain** o agrega dominio propio
3. Actualiza `APP_URL` y `SANCTUM_STATEFUL_DOMAINS`

---

## Troubleshooting

| Problema | Solución |
|----------|----------|
| 500 al iniciar | Verifica `APP_KEY` y `DATABASE_URL` |
| 419 en login web | `APP_URL` debe coincidir con la URL pública |
| App móvil sin conexión | Usa HTTPS y la URL `/api/health` |
| Migraciones fallan | Revisa logs; PostgreSQL debe estar linkeado |

Logs: Railway → servicio → **Deployments** → **View Logs**
