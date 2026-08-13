<?php

use App\Http\Controllers\Api\AuthApiController;
use App\Http\Controllers\Api\CompanyApiController;
use App\Http\Controllers\CommitmentController;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;

Route::get('/health', function () {
    try {
        DB::connection()->getPdo();
        $driver = DB::connection()->getDriverName();
        $tables = DB::select("SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname = 'public'");

        return response()->json([
            'ok' => true,
            'database' => $driver,
            'tables' => count($tables),
        ]);
    } catch (\Throwable $e) {
        return response()->json([
            'ok' => false,
            'error' => 'Sin conexion a base de datos',
            'hint' => 'Vincula DATABASE_URL desde Postgres--CyS al servicio web',
        ], 503);
    }
});

Route::post('/login', [AuthApiController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthApiController::class, 'logout']);
    Route::get('/me', [AuthApiController::class, 'me']);

    Route::get('/companies', [CompanyApiController::class, 'index']);

    Route::get('/commitments/calendar', [CommitmentController::class, 'calendar']);
    Route::get('/commitments/upcoming', [CommitmentController::class, 'upcoming']);
    Route::post('/commitments/check-conflict', [CommitmentController::class, 'checkConflict']);
    Route::get('/commitments', [CommitmentController::class, 'list']);
    Route::get('/commitments/{commitment}', [CommitmentController::class, 'show']);
    Route::post('/commitments', [CommitmentController::class, 'store']);
    Route::put('/commitments/{commitment}', [CommitmentController::class, 'update']);
    Route::patch('/commitments/{commitment}/status', [CommitmentController::class, 'updateStatus']);
    Route::post('/commitments/{commitment}/postpone', [CommitmentController::class, 'postpone']);
    Route::delete('/commitments/{commitment}', [CommitmentController::class, 'destroy']);
});
