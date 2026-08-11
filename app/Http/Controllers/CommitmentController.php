<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreCommitmentRequest;
use App\Models\Commitment;
use App\Models\Company;
use App\Services\ScheduleConflictService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class CommitmentController extends Controller
{
    public function __construct(
        private ScheduleConflictService $conflictService
    ) {}

    public function list(Request $request): JsonResponse
    {
        $commitments = Commitment::query()
            ->with('company')
            ->where('user_id', $request->user()->id)
            ->when($request->query('status'), fn ($q, $status) => $q->where('status', $status))
            ->when($request->query('company_id'), fn ($q, $companyId) => $q->where('company_id', $companyId))
            ->orderByDesc('starts_at')
            ->get();

        return response()->json($commitments);
    }

    public function show(Request $request, Commitment $commitment): JsonResponse
    {
        $this->authorizeCommitment($request, $commitment);
        $commitment->load('company');

        return response()->json($commitment);
    }

    public function index(Request $request): View
    {
        $companies = Company::orderBy('name')->get();

        return view('agenda.index', [
            'companies' => $companies,
        ]);
    }

    public function calendar(Request $request): JsonResponse
    {
        $start = $request->query('start');
        $end = $request->query('end');
        $companyId = $request->query('company_id');

        $query = Commitment::query()
            ->with('company')
            ->where('user_id', $request->user()->id)
            ->whereNot('status', 'cancelled');

        if ($start && $end) {
            $query->where('starts_at', '<', $end)
                ->where('ends_at', '>', $start);
        }

        if ($companyId) {
            $query->where('company_id', $companyId);
        }

        $events = $query->orderBy('starts_at')->get()->map->toCalendarEvent();

        return response()->json($events);
    }

    public function store(StoreCommitmentRequest $request): JsonResponse|RedirectResponse
    {
        $conflicts = $this->conflictService->findConflicts(
            $request->user(),
            $request->input('starts_at'),
            $request->input('ends_at')
        );

        if ($conflicts->isNotEmpty()) {
            $message = $this->conflictService->formatConflictMessage($conflicts);

            if ($request->expectsJson()) {
                return response()->json([
                    'message' => $message,
                    'conflicts' => $conflicts,
                ], 422);
            }

            return back()->withErrors(['schedule' => $message])->withInput();
        }

        $commitment = Commitment::create([
            ...$request->validated(),
            'user_id' => $request->user()->id,
            'sent_reminders' => [],
        ]);

        $commitment->load('company');

        if ($request->expectsJson()) {
            return response()->json([
                'message' => 'Compromiso agendado correctamente.',
                'commitment' => $commitment,
                'event' => $commitment->toCalendarEvent(),
            ], 201);
        }

        return redirect()->route('agenda.index')->with('success', 'Compromiso agendado correctamente.');
    }

    public function update(StoreCommitmentRequest $request, Commitment $commitment): JsonResponse|RedirectResponse
    {
        $this->authorizeCommitment($request, $commitment);

        $conflicts = $this->conflictService->findConflicts(
            $request->user(),
            $request->input('starts_at'),
            $request->input('ends_at'),
            $commitment->id
        );

        if ($conflicts->isNotEmpty()) {
            $message = $this->conflictService->formatConflictMessage($conflicts);

            if ($request->expectsJson()) {
                return response()->json([
                    'message' => $message,
                    'conflicts' => $conflicts,
                ], 422);
            }

            return back()->withErrors(['schedule' => $message])->withInput();
        }

        $commitment->update($request->validated());
        $commitment->load('company');

        if ($request->expectsJson()) {
            return response()->json([
                'message' => 'Compromiso actualizado.',
                'commitment' => $commitment,
                'event' => $commitment->toCalendarEvent(),
            ]);
        }

        return redirect()->route('agenda.index')->with('success', 'Compromiso actualizado.');
    }

    public function destroy(Request $request, Commitment $commitment): JsonResponse|RedirectResponse
    {
        $this->authorizeCommitment($request, $commitment);

        $commitment->delete();

        if ($request->expectsJson()) {
            return response()->json(['message' => 'Compromiso eliminado.']);
        }

        return redirect()->route('agenda.index')->with('success', 'Compromiso eliminado.');
    }

    public function upcoming(Request $request): JsonResponse
    {
        $commitments = Commitment::query()
            ->with('company')
            ->where('user_id', $request->user()->id)
            ->whereNotIn('status', ['completed', 'cancelled'])
            ->where('ends_at', '>=', now())
            ->orderBy('starts_at')
            ->limit(20)
            ->get();

        return response()->json($commitments);
    }

    public function checkConflict(Request $request): JsonResponse
    {
        $request->validate([
            'starts_at' => ['required', 'date'],
            'ends_at' => ['required', 'date', 'after:starts_at'],
            'exclude_id' => ['nullable', 'integer'],
        ], [
            'starts_at.required' => 'Indica la fecha y hora de inicio.',
            'ends_at.required' => 'Indica la fecha y hora de fin.',
            'ends_at.after' => 'La hora de fin debe ser posterior al inicio.',
        ], [
            'starts_at' => 'fecha de inicio',
            'ends_at' => 'fecha de fin',
        ]);

        $conflicts = $this->conflictService->findConflicts(
            $request->user(),
            $request->input('starts_at'),
            $request->input('ends_at'),
            $request->integer('exclude_id') ?: null
        );

        return response()->json([
            'has_conflict' => $conflicts->isNotEmpty(),
            'message' => $this->conflictService->formatConflictMessage($conflicts),
            'conflicts' => $conflicts,
        ]);
    }

    private function authorizeCommitment(Request $request, Commitment $commitment): void
    {
        abort_unless($commitment->user_id === $request->user()->id, 403);
    }
}
