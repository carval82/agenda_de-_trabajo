@extends('layouts.app')

@section('title', 'Agenda')

@push('head')
<link href="https://cdn.jsdelivr.net/npm/fullcalendar@6.1.15/index.global.min.css" rel="stylesheet">
@endpush

@section('content')
<div x-data="agendaApp()" x-init="init()" class="space-y-5">
    {{-- Stats dashboard --}}
    <div class="pda-stat-grid">
        <div class="pda-stat">
            <div class="pda-stat-label">Hoy</div>
            <div class="pda-stat-value text-blue-400" x-text="stats.today">0</div>
        </div>
        <div class="pda-stat">
            <div class="pda-stat-label">Esta semana</div>
            <div class="pda-stat-value text-emerald-400" x-text="stats.week">0</div>
        </div>
        <div class="pda-stat">
            <div class="pda-stat-label">LC Design</div>
            <div class="pda-stat-value" style="color:#60a5fa" x-text="stats.lcdesign">0</div>
        </div>
        <div class="pda-stat">
            <div class="pda-stat-label">Interveredanet</div>
            <div class="pda-stat-value" style="color:#34d399" x-text="stats.intervereda">0</div>
        </div>
    </div>

    <div class="grid xl:grid-cols-[320px_1fr] gap-5">
        {{-- Sidebar --}}
        <aside class="space-y-4">
            <div class="pda-panel p-5">
                <div class="pda-panel-title">
                    <h2>Mis empresas</h2>
                    <span class="pda-badge">Filtro</span>
                </div>
                <div class="space-y-3">
                    @foreach ($companies as $company)
                    <button type="button"
                        @click="toggleCompany({{ $company->id }})"
                        :class="selectedCompanies.includes({{ $company->id }}) ? 'active' : 'inactive'"
                        class="pda-company-card"
                        style="background: linear-gradient(135deg, {{ $company->color }}18, rgba(2,6,23,0.5)); border-left: 4px solid {{ $company->color }}">
                        <div class="pda-company-icon" style="background: {{ $company->color }}25; color: {{ $company->color }}">
                            @if($company->slug === 'lcdesign') 💻 @else 🌐 @endif
                        </div>
                        <div class="font-semibold">{{ $company->name }}</div>
                        <div class="text-xs text-slate-400 mt-1">{{ $company->tagline }}</div>
                    </button>
                    @endforeach
                </div>
            </div>

            <div class="pda-panel p-5">
                <div class="pda-panel-title">
                    <h2>Próximos compromisos</h2>
                    <span class="pda-badge">PDA</span>
                </div>
                <div class="space-y-3 max-h-[340px] overflow-y-auto pr-1" id="upcoming-list">
                    <p class="text-sm text-slate-500">Cargando agenda...</p>
                </div>
            </div>

            <button type="button" @click="openCreate()" class="pda-btn-primary">
                + Agendar nuevo trabajo
            </button>
        </aside>

        {{-- Calendar --}}
        <section class="pda-panel p-4 md:p-5">
            <div class="flex flex-wrap items-center justify-between gap-3 mb-4 pb-4 border-b border-slate-800">
                <div>
                    <h2 class="text-lg font-semibold">Calendario organizado</h2>
                    <p class="text-sm text-slate-400">Arrastra eventos · Detecta cruces automáticamente · Vista semanal recomendada</p>
                </div>
                <div class="flex gap-2 text-xs">
                    <span class="px-2.5 py-1 rounded-full bg-blue-500/15 text-blue-300 border border-blue-500/25">LC Design</span>
                    <span class="px-2.5 py-1 rounded-full bg-emerald-500/15 text-emerald-300 border border-emerald-500/25">Interveredanet</span>
                </div>
            </div>
            <div id="calendar"></div>
        </section>
    </div>

    {{-- Modal --}}
    <div x-show="modalOpen" x-cloak class="pda-modal-backdrop">
        <div class="pda-modal" @click.outside="modalOpen = false">
            <div class="pda-modal-header">
                <div>
                    <div class="pda-badge mb-2" x-text="editingId ? 'Editar' : 'Nuevo'"></div>
                    <h3 class="text-2xl font-semibold" x-text="editingId ? 'Editar compromiso' : 'Agendar compromiso'"></h3>
                    <p class="text-sm text-slate-400 mt-1">El sistema avisará si el horario se cruza con otro trabajo.</p>
                </div>
                <button type="button" @click="modalOpen = false" class="pda-btn-ghost">✕</button>
            </div>

            <form @submit.prevent="saveCommitment" class="space-y-5">
                <div class="pda-section">
                    <div class="pda-section-title">Información principal</div>
                    <div class="grid md:grid-cols-2 gap-4">
                        <div class="md:col-span-2">
                            <label class="pda-label">Título del trabajo</label>
                            <input x-model="form.title" required class="pda-input" placeholder="Ej: Instalación de red en cliente">
                        </div>
                        <div>
                            <label class="pda-label">Empresa</label>
                            <select x-model="form.company_id" required class="pda-select">
                                @foreach ($companies as $company)
                                <option value="{{ $company->id }}">{{ $company->name }}</option>
                                @endforeach
                            </select>
                        </div>
                        <div>
                            <label class="pda-label">Prioridad</label>
                            <select x-model="form.priority" class="pda-select">
                                <option value="low">● Baja</option>
                                <option value="medium">● Media</option>
                                <option value="high">● Alta</option>
                                <option value="urgent">● Urgente</option>
                            </select>
                        </div>
                    </div>
                </div>

                <div class="pda-section">
                    <div class="pda-section-title">Horario</div>
                    <div class="grid md:grid-cols-2 gap-4">
                        <div>
                            <label class="pda-label">Inicio</label>
                            <input type="datetime-local" x-model="form.starts_at" @change="checkConflict()" required class="pda-input">
                        </div>
                        <div>
                            <label class="pda-label">Fin</label>
                            <input type="datetime-local" x-model="form.ends_at" @change="checkConflict()" required class="pda-input">
                        </div>
                    </div>
                </div>

                <div class="pda-section">
                    <div class="pda-section-title">Detalles</div>
                    <div class="grid md:grid-cols-2 gap-4">
                        <div>
                            <label class="pda-label">Cliente / Proyecto</label>
                            <input x-model="form.client_name" class="pda-input" placeholder="Nombre del cliente">
                        </div>
                        <div>
                            <label class="pda-label">Ubicación</label>
                            <input x-model="form.location" class="pda-input" placeholder="Dirección o remoto">
                        </div>
                        <div class="md:col-span-2">
                            <label class="pda-label">Descripción</label>
                            <textarea x-model="form.description" rows="3" class="pda-textarea" placeholder="Notas, materiales, contactos..."></textarea>
                        </div>
                    </div>
                </div>

                <div class="pda-section">
                    <div class="pda-section-title">Recordatorios (estilo PDA)</div>
                    <div class="flex flex-wrap gap-2">
                        <template x-for="preset in reminderPresets" :key="preset">
                            <button type="button" @click="toggleReminder(preset)"
                                :class="form.reminder_minutes.includes(preset) ? 'active' : ''"
                                class="pda-chip" x-text="formatReminder(preset)"></button>
                        </template>
                    </div>
                </div>

                <div x-show="conflictMessage" x-cloak class="pda-alert-conflict" x-text="conflictMessage"></div>

                <div class="flex flex-wrap gap-3 pt-1">
                    <button type="submit" :disabled="saving" class="pda-btn-primary w-auto px-6 disabled:opacity-50">
                        <span x-text="saving ? 'Guardando...' : 'Guardar compromiso'"></span>
                    </button>
                    <button type="button" @click="modalOpen = false" class="pda-btn-ghost">Cancelar</button>
                    <button type="button" x-show="editingId" @click="deleteCommitment()" class="pda-btn-ghost ml-auto text-red-300 border-red-900/40">Eliminar</button>
                </div>
            </form>
        </div>
    </div>
</div>
@endsection

@push('scripts')
<script src="https://cdn.jsdelivr.net/npm/fullcalendar@6.1.15/index.global.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/@fullcalendar/core@6.1.15/locales/es.global.min.js"></script>
<script>
function agendaApp() {
    return {
        calendar: null,
        modalOpen: false,
        editingId: null,
        saving: false,
        conflictMessage: '',
        allEvents: [],
        stats: { today: 0, week: 0, lcdesign: 0, intervereda: 0 },
        selectedCompanies: @json($companies->pluck('id')),
        companySlugs: @json($companies->pluck('slug', 'id')),
        reminderPresets: [5, 15, 30, 60, 120, 1440],
        form: {
            company_id: {{ $companies->first()->id ?? 1 }},
            title: '',
            description: '',
            location: '',
            client_name: '',
            starts_at: '',
            ends_at: '',
            priority: 'medium',
            reminder_minutes: [15, 60],
        },

        init() {
            this.initCalendar();
            this.loadUpcoming();
        },

        initCalendar() {
            this.calendar = new FullCalendar.Calendar(document.getElementById('calendar'), {
                locale: 'es',
                initialView: 'timeGridWeek',
                headerToolbar: {
                    left: 'prev,next today',
                    center: 'title',
                    right: 'dayGridMonth,timeGridWeek,timeGridDay,listWeek'
                },
                slotMinTime: '06:00:00',
                slotMaxTime: '22:00:00',
                allDaySlot: false,
                height: 'auto',
                nowIndicator: true,
                selectable: true,
                selectMirror: true,
                editable: true,
                eventTimeFormat: { hour: '2-digit', minute: '2-digit', hour12: false },
                events: (info, success, failure) => {
                    const params = new URLSearchParams({ start: info.startStr, end: info.endStr });
                    fetch(`{{ route('agenda.calendar') }}?${params}`)
                        .then(r => r.json())
                        .then(events => {
                            this.allEvents = events;
                            this.updateStats(events);
                            success(events.filter(e =>
                                this.selectedCompanies.includes(Number(e.extendedProps.company_id))
                            ));
                        })
                        .catch(failure);
                },
                select: (info) => this.openCreate(info.start, info.end),
                eventClick: (info) => this.openEdit(info.event),
                eventDrop: (info) => this.moveEvent(info.event),
                eventResize: (info) => this.moveEvent(info.event),
            });
            this.calendar.render();
        },

        updateStats(events) {
            const now = new Date();
            const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
            const endOfDay = new Date(startOfDay); endOfDay.setDate(endOfDay.getDate() + 1);
            const startOfWeek = new Date(startOfDay); startOfWeek.setDate(startOfWeek.getDate() - startOfWeek.getDay());
            const endOfWeek = new Date(startOfWeek); endOfWeek.setDate(endOfWeek.getDate() + 7);

            this.stats.today = events.filter(e => {
                const s = new Date(e.start);
                return s >= startOfDay && s < endOfDay;
            }).length;

            this.stats.week = events.filter(e => {
                const s = new Date(e.start);
                return s >= startOfWeek && s < endOfWeek;
            }).length;

            this.stats.lcdesign = events.filter(e => e.extendedProps.company_slug === 'lcdesign').length;
            this.stats.intervereda = events.filter(e => e.extendedProps.company_slug === 'interveredanet').length;
        },

        toggleCompany(id) {
            if (this.selectedCompanies.includes(id)) {
                if (this.selectedCompanies.length > 1) {
                    this.selectedCompanies = this.selectedCompanies.filter(c => c !== id);
                }
            } else {
                this.selectedCompanies.push(id);
            }
            this.calendar.refetchEvents();
        },

        formatReminder(minutes) {
            if (minutes >= 1440) return `${minutes / 1440} día`;
            if (minutes >= 60) return `${minutes / 60} h`;
            return `${minutes} min`;
        },

        toggleReminder(minutes) {
            if (this.form.reminder_minutes.includes(minutes)) {
                this.form.reminder_minutes = this.form.reminder_minutes.filter(m => m !== minutes);
            } else {
                this.form.reminder_minutes.push(minutes);
                this.form.reminder_minutes.sort((a, b) => a - b);
            }
        },

        toLocalInput(date) {
            const d = new Date(date);
            d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
            return d.toISOString().slice(0, 16);
        },

        priorityLabel(p) {
            return { low: 'Baja', medium: 'Media', high: 'Alta', urgent: 'Urgente' }[p] || p;
        },

        timeUntil(dateStr) {
            const diff = new Date(dateStr) - new Date();
            if (diff < 0) return 'En curso';
            const mins = Math.floor(diff / 60000);
            if (mins < 60) return `En ${mins} min`;
            const hrs = Math.floor(mins / 60);
            if (hrs < 24) return `En ${hrs} h`;
            return `En ${Math.floor(hrs / 24)} d`;
        },

        openCreate(start = null, end = null) {
            this.editingId = null;
            this.conflictMessage = '';
            const now = start || new Date();
            const later = end || new Date(now.getTime() + 3600000);
            this.form = {
                company_id: {{ $companies->first()->id ?? 1 }},
                title: '', description: '', location: '', client_name: '',
                starts_at: this.toLocalInput(now),
                ends_at: this.toLocalInput(later),
                priority: 'medium',
                reminder_minutes: [15, 60],
            };
            this.modalOpen = true;
        },

        openEdit(event) {
            this.editingId = event.id;
            this.conflictMessage = '';
            this.form = {
                company_id: Number(event.extendedProps.company_id),
                title: event.title,
                description: event.extendedProps.description || '',
                location: event.extendedProps.location || '',
                client_name: event.extendedProps.client_name || '',
                starts_at: this.toLocalInput(event.start),
                ends_at: this.toLocalInput(event.end || event.start),
                priority: event.extendedProps.priority || 'medium',
                reminder_minutes: [15, 60],
            };
            this.modalOpen = true;
        },

        async checkConflict() {
            if (!this.form.starts_at || !this.form.ends_at) return;
            const res = await fetch('{{ route('agenda.check-conflict') }}', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                    'Accept': 'application/json',
                },
                body: JSON.stringify({
                    starts_at: this.form.starts_at,
                    ends_at: this.form.ends_at,
                    exclude_id: this.editingId,
                }),
            });
            const data = await res.json();
            this.conflictMessage = data.has_conflict ? data.message : '';
        },

        async saveCommitment() {
            this.saving = true;
            const url = this.editingId ? `/commitments/${this.editingId}` : '{{ route('commitments.store') }}';
            const res = await fetch(url, {
                method: this.editingId ? 'PUT' : 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                    'Accept': 'application/json',
                },
                body: JSON.stringify(this.form),
            });
            const data = await res.json();
            this.saving = false;
            if (!res.ok) {
                this.conflictMessage = data.message || 'No se pudo guardar.';
                return;
            }
            this.modalOpen = false;
            this.calendar.refetchEvents();
            this.loadUpcoming();
        },

        async deleteCommitment() {
            if (!this.editingId || !confirm('¿Eliminar este compromiso?')) return;
            await fetch(`/commitments/${this.editingId}`, {
                method: 'DELETE',
                headers: {
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                    'Accept': 'application/json',
                },
            });
            this.modalOpen = false;
            this.calendar.refetchEvents();
            this.loadUpcoming();
        },

        async moveEvent(event) {
            const res = await fetch(`/commitments/${event.id}`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                    'Accept': 'application/json',
                },
                body: JSON.stringify({
                    company_id: Number(event.extendedProps.company_id),
                    title: event.title,
                    description: event.extendedProps.description,
                    location: event.extendedProps.location,
                    client_name: event.extendedProps.client_name,
                    starts_at: this.toLocalInput(event.start),
                    ends_at: this.toLocalInput(event.end || event.start),
                    priority: event.extendedProps.priority,
                    reminder_minutes: [15, 60],
                }),
            });
            if (!res.ok) {
                const data = await res.json();
                alert(data.message || 'Conflicto de horario. Se revierte el cambio.');
                this.calendar.refetchEvents();
            } else {
                this.loadUpcoming();
            }
        },

        async loadUpcoming() {
            const res = await fetch('{{ route('agenda.upcoming') }}', { headers: { 'Accept': 'application/json' } });
            const container = document.getElementById('upcoming-list');
            if (!res.ok) {
                container.innerHTML = '<p class="text-sm text-slate-500">No se pudo cargar la agenda.</p>';
                return;
            }
            const items = await res.json();
            if (!items.length) {
                container.innerHTML = '<div class="text-center py-8"><div class="text-3xl mb-2">📋</div><p class="text-sm text-slate-500">Sin compromisos próximos.<br>¡Agenda tu primer trabajo!</p></div>';
                return;
            }
            container.innerHTML = items.map(item => `
                <div class="pda-upcoming-item">
                    <div class="flex items-start justify-between gap-2">
                        <div class="flex items-start gap-3 min-w-0">
                            <span class="w-2.5 h-2.5 mt-1.5 rounded-full shrink-0" style="background:${item.company.color}"></span>
                            <div class="min-w-0">
                                <div class="font-medium text-sm truncate">${item.title}</div>
                                <div class="text-xs text-slate-400">${item.company.name}</div>
                                <div class="text-xs text-slate-500 mt-1">${new Date(item.starts_at).toLocaleString('es-CR', { weekday:'short', day:'numeric', month:'short', hour:'2-digit', minute:'2-digit' })}</div>
                            </div>
                        </div>
                        <span class="pda-time-pill">${this.timeUntil(item.starts_at)}</span>
                    </div>
                </div>
            `).join('');
        },
    }
}
</script>
@endpush
