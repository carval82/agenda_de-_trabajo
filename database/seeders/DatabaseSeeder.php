<?php

namespace Database\Seeders;

use App\Models\Company;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        Company::insert([
            [
                'name' => 'LC Design',
                'slug' => 'lcdesign',
                'type' => 'software',
                'tagline' => 'Desarrollo de software',
                'color' => '#2563eb',
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'name' => 'Interveredanet.cr',
                'slug' => 'interveredanet',
                'type' => 'network',
                'tagline' => 'Lo hacemos posible — Redes y conectividad',
                'color' => '#059669',
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);

        User::updateOrCreate(
            ['email' => 'pcapacho24@gmail.com'],
            [
                'name' => 'Pcapacho',
                'password' => Hash::make('anaval33'),
            ]
        );
    }
}
