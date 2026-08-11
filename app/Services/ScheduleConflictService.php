<?php

namespace App\Services;

use App\Models\Commitment;
use App\Models\User;
use Illuminate\Support\Collection;

class ScheduleConflictService
{
    public function findConflicts(User $user, string $startsAt, string $endsAt, ?int $excludeId = null): Collection
    {
        $query = Commitment::query()
            ->with('company')
            ->where('user_id', $user->id)
            ->whereNotIn('status', ['completed', 'cancelled'])
            ->where('starts_at', '<', $endsAt)
            ->where('ends_at', '>', $startsAt);

        if ($excludeId) {
            $query->where('id', '!=', $excludeId);
        }

        return $query->orderBy('starts_at')->get();
    }

    public function hasConflict(User $user, string $startsAt, string $endsAt, ?int $excludeId = null): bool
    {
        return $this->findConflicts($user, $startsAt, $endsAt, $excludeId)->isNotEmpty();
    }

    public function formatConflictMessage(Collection $conflicts): string
    {
        if ($conflicts->isEmpty()) {
            return '';
        }

        $lines = $conflicts->map(function (Commitment $commitment) {
            return sprintf(
                '• %s (%s) — %s a %s',
                $commitment->title,
                $commitment->company->name,
                $commitment->starts_at->format('d/m/Y H:i'),
                $commitment->ends_at->format('H:i')
            );
        });

        return "Este horario se cruza con:\n".$lines->implode("\n");
    }
}
