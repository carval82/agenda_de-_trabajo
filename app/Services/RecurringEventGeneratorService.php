<?php

namespace App\Services;

use App\Models\Commitment;
use App\Models\RecurringEvent;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Collection;

class RecurringEventGeneratorService
{
    public function generateForUser(User $user, int $horizonDays = 90): int
    {
        $events = RecurringEvent::query()
            ->where('user_id', $user->id)
            ->where('is_active', true)
            ->get();

        $created = 0;
        foreach ($events as $event) {
            $created += $this->generateForEvent($event, $horizonDays);
        }

        return $created;
    }

    public function generateForEvent(RecurringEvent $event, int $horizonDays = 90): int
    {
        if (! $event->is_active) {
            return 0;
        }

        $tz = config('app.timezone');
        $from = Carbon::now($tz)->startOfDay();
        $to = $from->copy()->addDays($horizonDays);
        $startsOn = $event->starts_on->copy()->startOfDay();

        if ($startsOn->gt($to)) {
            return 0;
        }

        if ($from->lt($startsOn)) {
            $from = $startsOn->copy();
        }

        if ($event->ends_on && $event->ends_on->lt($from)) {
            return 0;
        }

        if ($event->ends_on && $event->ends_on->lt($to)) {
            $to = $event->ends_on->copy()->endOfDay();
        }

        $occurrences = $this->occurrencesBetween($event, $from, $to);
        $created = 0;

        foreach ($occurrences as $date) {
            $key = $date->format('Y-m-d');

            $exists = Commitment::query()
                ->where('recurring_event_id', $event->id)
                ->where('occurrence_key', $key)
                ->exists();

            if ($exists) {
                continue;
            }

            $startsAt = Carbon::create(
                $date->year,
                $date->month,
                $date->day,
                $event->time_hour,
                $event->time_minute,
                0,
                $tz
            );

            $endsAt = $startsAt->copy()->addMinutes($event->duration_minutes);

            Commitment::create([
                'user_id' => $event->user_id,
                'company_id' => $event->company_id,
                'recurring_event_id' => $event->id,
                'occurrence_key' => $key,
                'title' => $event->title,
                'description' => $this->buildDescription($event),
                'client_name' => $event->client_name,
                'starts_at' => $startsAt->utc(),
                'ends_at' => $endsAt->utc(),
                'priority' => $event->category === 'payment' || $event->category === 'invoice' ? 'high' : 'medium',
                'status' => 'scheduled',
                'reminder_minutes' => $event->defaultReminders(),
                'sent_reminders' => [],
            ]);

            $created++;
        }

        return $created;
    }

    /** @return Collection<int, Carbon> */
    private function occurrencesBetween(RecurringEvent $event, Carbon $from, Carbon $to): Collection
    {
        $dates = collect();
        $cursor = $from->copy();

        while ($cursor->lte($to)) {
            $match = match ($event->recurrence) {
                'daily' => true,
                'weekly' => $event->weekday && (int) $cursor->isoWeekday() === (int) $event->weekday,
                'monthly' => $this->matchesMonthlyDay($cursor, $event->day_of_month ?? $event->starts_on->day),
                'yearly' => $this->matchesYearly($cursor, $event),
                default => false,
            };

            if ($match && $cursor->gte($event->starts_on)) {
                $dates->push($cursor->copy());
            }

            $cursor->addDay();
        }

        return $dates;
    }

    private function matchesMonthlyDay(Carbon $date, int $targetDay): bool
    {
        $lastDay = $date->copy()->endOfMonth()->day;
        $effectiveDay = min($targetDay, $lastDay);

        return $date->day === $effectiveDay;
    }

    private function matchesYearly(Carbon $date, RecurringEvent $event): bool
    {
        $month = $event->month ?? $event->starts_on->month;
        $day = $event->day_of_month ?? $event->starts_on->day;

        if ((int) $date->month !== (int) $month) {
            return false;
        }

        return $this->matchesMonthlyDay($date, $day);
    }

    private function buildDescription(RecurringEvent $event): ?string
    {
        $parts = array_filter([
            $event->description,
            $event->amount ? 'Monto: $'.number_format((float) $event->amount, 2) : null,
            'Recordatorio permanente · '.$event->recurrenceLabel(),
        ]);

        return $parts ? implode("\n", $parts) : null;
    }
}
