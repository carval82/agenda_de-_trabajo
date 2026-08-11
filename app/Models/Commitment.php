<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Commitment extends Model
{
    protected $fillable = [
        'user_id',
        'company_id',
        'title',
        'description',
        'location',
        'client_name',
        'starts_at',
        'ends_at',
        'all_day',
        'priority',
        'status',
        'reminder_minutes',
        'sent_reminders',
    ];

    protected function casts(): array
    {
        return [
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'all_day' => 'boolean',
            'reminder_minutes' => 'array',
            'sent_reminders' => 'array',
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

    public function isActive(): bool
    {
        return ! in_array($this->status, ['completed', 'cancelled'], true);
    }

    public function toCalendarEvent(): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'start' => $this->starts_at->toIso8601String(),
            'end' => $this->ends_at->toIso8601String(),
            'allDay' => $this->all_day,
            'backgroundColor' => $this->company->color,
            'borderColor' => $this->company->color,
            'extendedProps' => [
                'company_id' => $this->company_id,
                'company' => $this->company->name,
                'company_slug' => $this->company->slug,
                'priority' => $this->priority,
                'status' => $this->status,
                'location' => $this->location,
                'client_name' => $this->client_name,
                'description' => $this->description,
            ],
        ];
    }
}
