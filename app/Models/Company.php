<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Company extends Model
{
    protected $fillable = [
        'name',
        'slug',
        'type',
        'tagline',
        'color',
    ];

    public function commitments(): HasMany
    {
        return $this->hasMany(Commitment::class);
    }
}
