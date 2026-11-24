import 'package:flutter/material.dart';

/// Pesos colombianos sin decimales: $87.000
String money(num? value) {
  final amount = (value ?? 0).round();
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}\$$buffer';
}

/// Pesos con hasta 2 decimales para valores pequenos: $33,33 (valor por minuto).
String moneyDecimal(num? value) {
  final cents = ((value ?? 0) * 100).round();
  final whole = money(cents ~/ 100);
  final rest = (cents % 100).abs();
  return rest == 0 ? whole : '$whole,${rest.toString().padLeft(2, '0')}';
}

/// Solo letras y numeros, en mayusculas (como la guarda el servidor).
String cleanPlate(String? value) => (value ?? '').toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

/// ABC123 -> ABC 123
String displayPlate(String? plate) {
  final clean = cleanPlate(plate);
  return clean.length > 3 ? '${clean.substring(0, 3)} ${clean.substring(3)}' : clean;
}

/// Hora local en 12 horas: 10:15 AM
String hhmm(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
}

/// 2h 30m
String duration(Duration value) {
  final minutes = value.inMinutes < 0 ? 0 : value.inMinutes;
  final hours = minutes ~/ 60;
  return hours > 0 ? '${hours}h ${minutes % 60}m' : '${minutes}m';
}

const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const _days = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];

/// 28 nov 2026
String shortDate(DateTime? value) {
  if (value == null) return '—';
  return '${value.day} ${_months[value.month - 1]} ${value.year}';
}

/// MAR, 10 DE NOV
String todayLabel(DateTime value) => '${_days[value.weekday - 1]}, ${value.day} DE ${_months[value.month - 1].toUpperCase()}';

/// Fecha sin hora (las mensualidades usan fechas tipo 2026-11-28).
DateTime? parseDate(dynamic value) => value == null ? null : DateTime.tryParse(value.toString());

class VehicleMeta {
  final String type;
  final String label;
  final IconData icon;
  /// CAR = espacios de carro y tablero de llaves; MOTORCYCLE = espacios de moto y casilleros de casco.
  final String category;
  const VehicleMeta(this.type, this.label, this.icon, [this.category = 'CAR']);

  /// Se parquea en espacios de moto y guarda cascos: moto, bicicleta y los tipos creados "como moto".
  bool get compact => category == 'MOTORCYCLE';
  /// La bicicleta deja un casco; las motos y los tipos "como moto", hasta dos.
  int get maxHelmets => type == 'BICYCLE' ? 1 : 2;
  /// true = tipo agregado por el parqueadero en Configuracion.
  bool get custom => !_baseTypes.any((base) => base.type == type);
}

/// Los 4 tipos con los que nace todo parqueadero.
const _baseTypes = <VehicleMeta>[
  VehicleMeta('CAR', 'Carro', Icons.directions_car_filled_outlined, 'CAR'),
  VehicleMeta('MOTORCYCLE', 'Moto', Icons.two_wheeler, 'MOTORCYCLE'),
  VehicleMeta('HEAVY', 'Carga', Icons.local_shipping_outlined, 'CAR'),
  VehicleMeta('BICYCLE', 'Bicicleta', Icons.pedal_bike, 'MOTORCYCLE'),
];

/// Tipos activos del parqueadero, en orden. Empieza con los 4 basicos y se reemplaza con el catalogo
/// de tarifas del servidor (registerVehicleTypes), que incluye los tipos agregados en Configuracion.
final List<VehicleMeta> vehicleTypes = List.of(_baseTypes);

/// Todos los tipos conocidos, incluidos los ya eliminados: el historial sigue mostrando su nombre.
final Map<String, VehicleMeta> _knownTypes = {for (final type in _baseTypes) type.type: type};

/// Carga el catalogo del parqueadero: [code, nombre, categoria] de cada tipo activo.
void registerVehicleTypes(Iterable<(String, String, String)> catalog) {
  final items = catalog.toList();
  if (items.isEmpty) return;
  final active = <VehicleMeta>[];
  for (final (code, name, category) in items) {
    final base = _baseTypes.where((item) => item.type == code).firstOrNull;
    final moto = category == 'MOTORCYCLE';
    final meta = base ?? VehicleMeta(code, name, moto ? Icons.electric_scooter : Icons.airport_shuttle_outlined, moto ? 'MOTORCYCLE' : 'CAR');
    _knownTypes[code] = meta;
    active.add(meta);
  }
  vehicleTypes
    ..clear()
    ..addAll(active);
}

/// CAMIONETA_4X4 -> Camioneta 4x4 (para tipos que no estan en el catalogo cargado).
String _humanize(String code) {
  final text = code.replaceAll('_', ' ').toLowerCase();
  return text.isEmpty ? 'Vehículo' : text[0].toUpperCase() + text.substring(1);
}

VehicleMeta vehicleMeta(String? type) {
  final code = type ?? 'CAR';
  return _knownTypes[code] ?? VehicleMeta(code, _humanize(code), Icons.directions_car_outlined);
}

String paymentLabel(String? method) => method == 'ONLINE' ? 'En línea' : 'Efectivo';
