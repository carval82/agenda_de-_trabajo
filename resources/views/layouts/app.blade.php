<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>@yield('title', 'Agenda de Trabajo') — LC Design & Interveredanet</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="icon" type="image/png" href="{{ asset('image/logo_app2.png') }}">
    <link rel="stylesheet" href="{{ asset('css/agenda.css') }}">
    <script src="https://cdn.tailwindcss.com"></script>
    <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
    @stack('head')
</head>
<body class="pda-body">
<div class="pda-shell">
    @auth
    <header class="pda-header">
        <div class="max-w-[1400px] mx-auto px-4 py-3 flex items-center justify-between gap-4">
            <div class="flex items-center gap-3 min-w-0">
                <img src="{{ asset('image/logo_app2.png') }}" alt="PDA Agenda de Trabajo" class="pda-brand-logo pda-brand-logo--compact shrink-0">
                <div class="min-w-0 hidden sm:block">
                    <h1 class="font-semibold leading-tight truncate">Agenda de Trabajo</h1>
                    <p class="text-xs text-slate-400 truncate">LC Design · Interveredanet.cr</p>
                </div>
            </div>

            <div class="flex items-center gap-3">
                <div class="pda-clock hidden sm:block" id="live-clock">--:--</div>
                <span class="text-sm text-slate-400 hidden md:inline">{{ auth()->user()->name }}</span>
                <form method="POST" action="{{ route('logout') }}">
                    @csrf
                    <button type="submit" class="pda-btn-ghost text-sm">Salir</button>
                </form>
            </div>
        </div>
    </header>
    @endauth

    <main class="@auth max-w-[1400px] mx-auto px-4 py-6 @else pda-auth-wrap @endauth">
        @if (session('success'))
            <div class="mb-4 rounded-xl border border-emerald-700/50 bg-emerald-950/40 px-4 py-3 text-emerald-200">{{ session('success') }}</div>
        @endif

        @if ($errors->any())
            <div class="mb-4 rounded-xl border border-red-700/50 bg-red-950/40 px-4 py-3 text-red-200 whitespace-pre-line">
                @foreach ($errors->all() as $error)
                    <div>{{ $error }}</div>
                @endforeach
            </div>
        @endif

        @yield('content')
    </main>
</div>

@auth
<script>
(function tickClock() {
    const el = document.getElementById('live-clock');
    if (!el) return;
    const now = new Date();
    el.textContent = now.toLocaleTimeString('es-CR', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    setTimeout(tickClock, 1000);
})();
</script>
@endauth

@stack('scripts')
</body>
</html>
