<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class RecurringEvent extends Model
{
    protected $fillable = [
        'user_id',
        'company_id',
        'title',
        'description',
        'client_name',
        'category',
        'amount',
        'recurrence',
        'day_of_month',
        'weekday',
        'month',
        'time_hour',
        'time_minute',
        'duration_minutes',
        'reminder_minutes',
        'starts_on',
        'ends_on',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'starts_on' => 'date',
            'ends_on' => 'date',
            'is_active' => 'boolean',
            'reminder_minutes' => 'array',
            'amount' => 'decimal:2',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function commitments(): HasMany
    {
        return $this->hasMany(Commitment::class);
    }

    public function defaultReminders(): array
    {
        return $this->reminder_minutes ?? [1440, 60, 15];
    }

    public function recurrenceLabel(): string
    {
        return match ($this->recurrence) {
            'daily' => 'Cada día',
            'weekly' => 'Cada semana',
            'monthly' => 'Cada mes',
            'yearly' => 'Cada año',
            default => $this->recurrence,
        };
    }
}
