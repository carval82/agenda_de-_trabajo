<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreRecurringEventRequest;
use App\Models\Commitment;
use App\Models\RecurringEvent;
use App\Services\RecurringEventGeneratorService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RecurringEventController extends Controller
{
    public function __construct(
        private RecurringEventGeneratorService $generator
    ) {}

    public function index(Request $request): JsonResponse
    {
        $events = RecurringEvent::query()
            ->with('company')
            ->where('user_id', $request->user()->id)
            ->orderByDesc('is_active')
            ->orderBy('title')
            ->get();

        return response()->json($events);
    }

    public function store(StoreRecurringEventRequest $request): JsonResponse
    {
        $event = RecurringEvent::create([
            ...$request->validated(),
            'user_id' => $request->user()->id,
            'duration_minutes' => $request->input('duration_minutes', 30),
            'is_active' => $request->boolean('is_active', true),
        ]);

        $event->load('company');
        $generated = $this->generator->generateForEvent($event);

        return response()->json([
            'message' => 'Recordatorio permanente creado.',
            'recurring_event' => $event,
            'generated_commitments' => $generated,
        ], 201);
    }

    public function update(StoreRecurringEventRequest $request, RecurringEvent $recurringEvent): JsonResponse
    {
        $this->authorizeEvent($request, $recurringEvent);

        $recurringEvent->update($request->validated());
        $recurringEvent->load('company');

        // Regenerar ocurrencias futuras que aún no pasaron
        Commitment::query()
            ->where('recurring_event_id', $recurringEvent->id)
            ->where('starts_at', '>', now())
            ->where('status', 'scheduled')
            ->delete();

        $generated = $this->generator->generateForEvent($recurringEvent);

        return response()->json([
            'message' => 'Recordatorio permanente actualizado.',
            'recurring_event' => $recurringEvent,
            'generated_commitments' => $generated,
        ]);
    }

    public function destroy(Request $request, RecurringEvent $recurringEvent): JsonResponse
    {
        $this->authorizeEvent($request, $recurringEvent);

        $recurringEvent->update(['is_active' => false]);

        Commitment::query()
            ->where('recurring_event_id', $recurringEvent->id)
            ->where('starts_at', '>', now())
            ->where('status', 'scheduled')
            ->update(['status' => 'cancelled']);

        return response()->json(['message' => 'Recordatorio permanente desactivado.']);
    }

    public function generate(Request $request): JsonResponse
    {
        $count = $this->generator->generateForUser($request->user());

        return response()->json([
            'message' => "Se generaron {$count} recordatorios.",
            'generated' => $count,
        ]);
    }

    private function authorizeEvent(Request $request, RecurringEvent $event): void
    {
        abort_unless($event->user_id === $request->user()->id, 403);
    }
}
