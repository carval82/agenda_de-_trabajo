<?php

namespace App\Console\Commands;

use App\Models\Commitment;
use App\Models\User;
use App\Notifications\CommitmentReminderNotification;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Notification;

class SendCommitmentReminders extends Command
{
    protected $signature = 'agenda:send-reminders';

    protected $description = 'Envía recordatorios de compromisos próximos (estilo PDA)';

    public function handle(): int
    {
        $now = now();
        $sent = 0;

        Commitment::query()
            ->with(['user', 'company'])
            ->whereNotIn('status', ['completed', 'cancelled'])
            ->where('ends_at', '>', $now)
            ->chunkById(100, function ($commitments) use ($now, &$sent) {
                foreach ($commitments as $commitment) {
                    $sent += $this->processCommitment($commitment, $now);
                }
            });

        $this->info("Recordatorios enviados: {$sent}");

        return self::SUCCESS;
    }

    private function processCommitment(Commitment $commitment, $now): int
    {
        $minutes = $commitment->reminder_minutes ?? [15, 60];
        $sentReminders = $commitment->sent_reminders ?? [];
        $count = 0;

        foreach ($minutes as $minute) {
            $key = (string) $minute;

            if (in_array($key, $sentReminders, true)) {
                continue;
            }

            $reminderAt = $commitment->starts_at->copy()->subMinutes((int) $minute);

            if ($now->greaterThanOrEqualTo($reminderAt) && $now->lessThan($commitment->starts_at)) {
                $commitment->user->notify(new CommitmentReminderNotification($commitment, (int) $minute));
                $sentReminders[] = $key;
                $count++;
            }
        }

        if ($count > 0) {
            $commitment->update(['sent_reminders' => $sentReminders]);
        }

        return $count;
    }
}
