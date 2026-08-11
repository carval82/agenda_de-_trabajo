<?php

namespace App\Http\Requests;

use Carbon\Carbon;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreCommitmentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'starts_at' => $this->normalizeDateTime($this->input('starts_at')),
            'ends_at' => $this->normalizeDateTime($this->input('ends_at')),
        ]);
    }

    private function normalizeDateTime(?string $value): ?string
    {
        if ($value === null || $value === '') {
            return $value;
        }

        $hasOffset = str_ends_with($value, 'Z')
            || preg_match('/[+-]\d{2}:\d{2}$/', $value);

        $carbon = $hasOffset
            ? Carbon::parse($value)
            : Carbon::parse($value, config('app.timezone'));

        return $carbon->utc()->toIso8601String();
    }

    public function rules(): array
    {
        return [
            'company_id' => ['required', 'exists:companies,id'],
            'title' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'location' => ['nullable', 'string', 'max:255'],
            'client_name' => ['nullable', 'string', 'max:255'],
            'starts_at' => ['required', 'date'],
            'ends_at' => ['required', 'date', 'after:starts_at'],
            'all_day' => ['sometimes', 'boolean'],
            'priority' => ['required', Rule::in(['low', 'medium', 'high', 'urgent'])],
            'status' => ['sometimes', Rule::in(['scheduled', 'in_progress', 'completed', 'cancelled'])],
            'reminder_minutes' => ['nullable', 'array'],
            'reminder_minutes.*' => ['integer', 'min:1', 'max:10080'],
        ];
    }

    public function messages(): array
    {
        return [
            'company_id.required' => 'Selecciona una empresa.',
            'company_id.exists' => 'La empresa seleccionada no es válida.',
            'title.required' => 'El título del trabajo es obligatorio.',
            'title.max' => 'El título no puede superar 255 caracteres.',
            'starts_at.required' => 'Indica la fecha y hora de inicio.',
            'starts_at.date' => 'La fecha de inicio no es válida.',
            'ends_at.required' => 'Indica la fecha y hora de fin.',
            'ends_at.date' => 'La fecha de fin no es válida.',
            'ends_at.after' => 'La hora de fin debe ser posterior al inicio.',
            'priority.required' => 'Selecciona una prioridad.',
            'priority.in' => 'La prioridad seleccionada no es válida.',
        ];
    }

    public function attributes(): array
    {
        return [
            'company_id' => 'empresa',
            'title' => 'título del trabajo',
            'starts_at' => 'fecha de inicio',
            'ends_at' => 'fecha de fin',
            'priority' => 'prioridad',
            'client_name' => 'cliente',
            'location' => 'ubicación',
            'description' => 'descripción',
        ];
    }
}
