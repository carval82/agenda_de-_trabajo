<?php

use App\Http\Controllers\Auth\AuthController;
use App\Http\Controllers\CommitmentController;
use Illuminate\Support\Facades\Route;

Route::middleware('guest')->group(function () {
    Route::get('/login', [AuthController::class, 'showLogin'])->name('login');
    Route::post('/login', [AuthController::class, 'login']);
    Route::get('/register', [AuthController::class, 'showRegister'])->name('register');
    Route::post('/register', [AuthController::class, 'register']);
});

Route::middleware('auth')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout'])->name('logout');

    Route::get('/', [CommitmentController::class, 'index'])->name('agenda.index');
    Route::get('/agenda/calendar', [CommitmentController::class, 'calendar'])->name('agenda.calendar');
    Route::get('/agenda/upcoming', [CommitmentController::class, 'upcoming'])->name('agenda.upcoming');
    Route::post('/agenda/check-conflict', [CommitmentController::class, 'checkConflict'])->name('agenda.check-conflict');
    Route::post('/commitments', [CommitmentController::class, 'store'])->name('commitments.store');
    Route::put('/commitments/{commitment}', [CommitmentController::class, 'update'])->name('commitments.update');
    Route::patch('/commitments/{commitment}/status', [CommitmentController::class, 'updateStatus'])->name('commitments.status');
    Route::post('/commitments/{commitment}/postpone', [CommitmentController::class, 'postpone'])->name('commitments.postpone');
    Route::delete('/commitments/{commitment}', [CommitmentController::class, 'destroy'])->name('commitments.destroy');
});
