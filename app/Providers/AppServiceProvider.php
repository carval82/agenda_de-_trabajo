<?php

namespace App\Providers;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        $this->configureDatabase();
        
        if ($this->app->environment('production')) {
            URL::forceScheme('https');
        }
    }

    private function configureDatabase(): void
    {
        if (env('DATABASE_URL')) {
            config([
                'database.default' => 'pgsql',
                'database.connections.pgsql.url' => env('DATABASE_URL'),
            ]);

            return;
        }

        if (env('PGHOST')) {
            config([
                'database.default' => 'pgsql',
                'database.connections.pgsql.host' => env('PGHOST'),
                'database.connections.pgsql.port' => env('PGPORT', '5432'),
                'database.connections.pgsql.database' => env('PGDATABASE', env('POSTGRES_DB', 'railway')),
                'database.connections.pgsql.username' => env('PGUSER', env('POSTGRES_USER', 'postgres')),
                'database.connections.pgsql.password' => env('PGPASSWORD', env('POSTGRES_PASSWORD', '')),
                'database.connections.pgsql.sslmode' => env('DB_SSLMODE', 'prefer'),
            ]);
        }
    }
}
