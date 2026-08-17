<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreRecurringEventRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'company_id' => ['required', 'exists:companies,id'],
            'title' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'client_name' => ['nullable', 'string', 'max:255'],
            'category' => ['required', Rule::in(['payment', 'invoice', 'reminder', 'general'])],
            'amount' => ['nullable', 'numeric', 'min:0'],
            'recurrence' => ['required', Rule::in(['daily', 'weekly', 'monthly', 'yearly'])],
            'day_of_month' => ['nullable', 'integer', 'min:1', 'max:31'],
            'weekday' => ['nullable', 'integer', 'min:1', 'max:7'],
            'month' => ['nullable', 'integer', 'min:1', 'max:12'],
            'time_hour' => ['required', 'integer', 'min:0', 'max:23'],
            'time_minute' => ['required', 'integer', 'min:0', 'max:59'],
            'duration_minutes' => ['nullable', 'integer', 'min:15', 'max:1440'],
            'reminder_minutes' => ['nullable', 'array'],
            'reminder_minutes.*' => ['integer', 'min:1', 'max:10080'],
            'starts_on' => ['required', 'date'],
            'ends_on' => ['nullable', 'date', 'after_or_equal:starts_on'],
            'is_active' => ['sometimes', 'boolean'],
        ];
    }

    public function messages(): array
    {
        return [
            'title.required' => 'El título es obligatorio.',
            'company_id.required' => 'Selecciona una empresa.',
            'recurrence.required' => 'Indica cada cuánto se repite.',
            'starts_on.required' => 'Indica desde cuándo aplica.',
        ];
    }
}
