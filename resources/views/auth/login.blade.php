@extends('layouts.app')

@section('title', 'Iniciar sesión')

@section('content')
<div class="pda-auth-card">
    <div class="pda-auth-hero">
        <img src="{{ asset('image/logo_app.png') }}" alt="PDA Agenda de Trabajo" class="pda-brand-logo pda-brand-logo--hero">
        <img src="{{ asset('image/logo_app2.png') }}" alt="PDA" class="pda-brand-logo pda-brand-logo--compact pda-brand-logo--auth-strip">
        <h2 class="text-3xl font-bold leading-tight">Tu agenda inteligente</h2>
        <p class="text-slate-400 mt-3 max-w-md">Organiza trabajos de desarrollo y redes sin que se crucen. Recordatorios automáticos, estilo asistente personal.</p>

        <div class="mt-8 space-y-1">
            <div class="pda-feature">
                <div class="pda-feature-icon">📅</div>
                <div><strong>Calendario organizado</strong><br>Vista semanal, mensual y por lista.</div>
            </div>
            <div class="pda-feature">
                <div class="pda-feature-icon">⚡</div>
                <div><strong>Anti-cruce de horarios</strong><br>No podrás agendar dos trabajos a la vez.</div>
            </div>
            <div class="pda-feature">
                <div class="pda-feature-icon">🔔</div>
                <div><strong>Recordatorios PDA</strong><br>Avisos antes de cada compromiso.</div>
            </div>
        </div>

        <div class="mt-10 flex flex-wrap gap-2">
            <span class="px-3 py-1.5 rounded-full text-xs bg-blue-500/15 text-blue-300 border border-blue-500/25">LC Design</span>
            <span class="px-3 py-1.5 rounded-full text-xs bg-emerald-500/15 text-emerald-300 border border-emerald-500/25">Interveredanet.cr</span>
        </div>
    </div>

    <div class="pda-auth-form">
        <h3 class="text-2xl font-semibold mb-1">Iniciar sesión</h3>
        <p class="text-sm text-slate-400 mb-8">Accede a tu agenda de trabajo</p>

        <form method="POST" action="{{ route('login') }}" class="space-y-4">
            @csrf
            <div>
                <label class="pda-label">Correo electrónico</label>
                <input type="email" name="email" value="{{ old('email', 'pcapacho24@gmail.com') }}" required class="pda-input" placeholder="tu@correo.com">
            </div>
            <div>
                <label class="pda-label">Contraseña</label>
                <input type="password" name="password" required class="pda-input" placeholder="••••••••">
            </div>
            <label class="flex items-center gap-2 text-sm text-slate-400">
                <input type="checkbox" name="remember" class="rounded border-slate-600">
                Recordarme en este equipo
            </label>
            <button type="submit" class="pda-btn-primary">Entrar a la agenda</button>
        </form>

        <p class="text-center text-sm text-slate-400 mt-8">
            ¿Primera vez?
            <a href="{{ route('register') }}" class="text-blue-400 hover:underline font-medium">Crear cuenta</a>
        </p>
    </div>
</div>
@endsection
