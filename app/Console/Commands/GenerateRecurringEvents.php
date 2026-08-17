<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Services\RecurringEventGeneratorService;
use Illuminate\Console\Command;

class GenerateRecurringEvents extends Command
{
    protected $signature = 'agenda:generate-recurring {--user= : ID de usuario específico}';

    protected $description = 'Genera compromisos a partir de recordatorios permanentes';

    public function handle(RecurringEventGeneratorService $generator): int
    {
        $userId = $this->option('user');

        if ($userId) {
            $user = User::find($userId);
            if (! $user) {
                $this->error('Usuario no encontrado.');

                return self::FAILURE;
            }
            $count = $generator->generateForUser($user);
            $this->info("Generados {$count} compromisos para usuario {$userId}.");

            return self::SUCCESS;
        }

        $total = 0;
        User::query()->each(function (User $user) use ($generator, &$total) {
            $total += $generator->generateForUser($user);
        });

        $this->info("Generados {$total} compromisos recurrentes.");

        return self::SUCCESS;
    }
}
