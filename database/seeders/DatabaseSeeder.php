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
        Company::updateOrCreate(
            ['slug' => 'lcdesign'],
            [
                'name' => 'LC Design',
                'type' => 'software',
                'tagline' => 'Desarrollo de software',
                'color' => '#2563eb',
            ]
        );

        Company::updateOrCreate(
            ['slug' => 'interveredanet'],
            [
                'name' => 'Interveredanet.cr',
                'type' => 'network',
                'tagline' => 'Lo hacemos posible — Redes y conectividad',
                'color' => '#059669',
            ]
        );

        User::updateOrCreate(
            ['email' => 'pcapacho24@gmail.com'],
            [
                'name' => 'Pcapacho',
                'password' => Hash::make('anaval33'),
            ]
        );
    }
}
