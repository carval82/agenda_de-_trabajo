# Agenda de Trabajo — PDA

Agenda inteligente para organizar compromisos de **LC Design** (desarrollo de software) e **Interveredanet.cr** (redes), con detección de cruces de horario y recordatorios estilo PDA.

## Stack

- **Web/API:** Laravel 12 + Sanctum + SQLite (por defecto)
- **App móvil:** Flutter (`mobile/agenda_app`)

## Funciones principales

- Calendario semanal/mensual con vista por empresa
- **Anti-cruce:** no permite agendar dos trabajos en el mismo horario
- Recordatorios configurables (5 min, 15 min, 1 h, 1 día...)
- Filtro por empresa (LC Design / Interveredanet)
- API REST para la app Flutter
- Notificaciones locales en Flutter + email/base de datos en servidor

## Instalación web

```bash
cd "c:\xampp\htdocs\laravel\agenda_de _trabajo"
composer install
cp .env.example .env   # si hace falta
php artisan key:generate
php artisan migrate --seed
php artisan serve
```

Abrir: `http://127.0.0.1:8000`

### Usuario demo

- Email: `pcapacho24@gmail.com`
- Contraseña: `anaval33`

## Recordatorios en servidor (cron)

Ejecutar cada minuto:

```bash
php artisan schedule:work
```

O en producción, agregar al cron:

```
* * * * * php /ruta/al/proyecto/artisan schedule:run >> /dev/null 2>&1
```

## App Flutter

```bash
cd mobile/agenda_app
flutter pub get
flutter run
```

Configura la URL del API en `lib/config/api_config.dart`:

- Emulador Android → `http://10.0.2.2/...`
- Dispositivo físico → IP de tu PC, ej. `http://192.168.1.50/agenda_de%20_trabajo/public/api`
- Con `php artisan serve` → `http://10.0.2.2:8000/api`

## API (Sanctum)

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/api/login` | Login (email, password, device_name) |
| GET | `/api/companies` | Empresas |
| GET | `/api/commitments/calendar` | Eventos calendario |
| GET | `/api/commitments/upcoming` | Próximos compromisos |
| POST | `/api/commitments/check-conflict` | Verificar cruce |
| CRUD | `/api/commitments` | Gestionar compromisos |

## Empresas precargadas

1. **LC Design** — Desarrollo de software (`#2563eb`)
2. **Interveredanet.cr** — Lo hacemos posible — Redes (`#059669`)

## Despliegue en Railway

Ver guía completa: **[RAILWAY.md](RAILWAY.md)**

Resumen rápido:

1. Conecta el repo [carval82/agenda_de-_trabajo](https://github.com/carval82/agenda_de-_trabajo) en Railway
2. Agrega **PostgreSQL**
3. Configura variables: `APP_KEY`, `APP_URL`, `DB_CONNECTION=pgsql`, `DATABASE_URL=${{Postgres.DATABASE_URL}}`
4. Genera dominio público en Networking
5. Ejecuta una vez: `php artisan db:seed --force`
