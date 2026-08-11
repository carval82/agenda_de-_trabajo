@extends('layouts.app')

@section('title', 'Registro')

@section('content')
<div class="pda-auth-card" style="max-width:520px">
    <div class="pda-auth-form" style="grid-column: 1 / -1">
        <div class="text-center mb-8">
            <img src="{{ asset('image/logo_app2.png') }}" alt="PDA Agenda de Trabajo" class="pda-brand-logo pda-brand-logo--compact mx-auto mb-4">
            <h3 class="text-2xl font-semibold">Crear cuenta</h3>
            <p class="text-sm text-slate-400 mt-2">Empieza a organizar tus trabajos hoy</p>
        </div>

        <form method="POST" action="{{ route('register') }}" class="space-y-4">
            @csrf
            <div>
                <label class="pda-label">Nombre completo</label>
                <input type="text" name="name" value="{{ old('name') }}" required class="pda-input">
            </div>
            <div>
                <label class="pda-label">Correo electrónico</label>
                <input type="email" name="email" value="{{ old('email') }}" required class="pda-input">
            </div>
            <div>
                <label class="pda-label">Contraseña</label>
                <input type="password" name="password" required class="pda-input">
            </div>
            <div>
                <label class="pda-label">Confirmar contraseña</label>
                <input type="password" name="password_confirmation" required class="pda-input">
            </div>
            <button type="submit" class="pda-btn-primary" style="background:linear-gradient(135deg,#059669,#047857)">Registrarme</button>
        </form>

        <p class="text-center text-sm text-slate-400 mt-8">
            <a href="{{ route('login') }}" class="text-blue-400 hover:underline">← Volver al login</a>
        </p>
    </div>
</div>
@endsection
