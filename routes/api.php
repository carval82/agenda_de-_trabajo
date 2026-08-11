<?php

use App\Http\Controllers\Api\AuthApiController;
use App\Http\Controllers\Api\CompanyApiController;
use App\Http\Controllers\CommitmentController;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => response()->json(['ok' => true]));

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
    Route::delete('/commitments/{commitment}', [CommitmentController::class, 'destroy']);
});
