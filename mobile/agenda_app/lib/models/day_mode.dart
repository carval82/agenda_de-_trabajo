enum DayMode {
  pending,
  active,
  rest;

  String get label {
    switch (this) {
      case DayMode.active:
        return 'Día activo';
      case DayMode.rest:
        return 'Modo reposo';
      case DayMode.pending:
        return 'Esperando briefing';
    }
  }
}
