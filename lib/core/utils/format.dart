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
  const VehicleMeta(this.type, this.label, this.icon);

  /// Motos y bicicletas usan espacios de moto y casilleros de casco; carros y carga, espacios de carro y llaves.
  bool get compact => type == 'MOTORCYCLE' || type == 'BICYCLE';
  int get maxHelmets => type == 'MOTORCYCLE' ? 2 : 1;
}

const vehicleTypes = <VehicleMeta>[
  VehicleMeta('CAR', 'Carro', Icons.directions_car_filled_outlined),
  VehicleMeta('MOTORCYCLE', 'Moto', Icons.two_wheeler),
  VehicleMeta('HEAVY', 'Carga', Icons.local_shipping_outlined),
  VehicleMeta('BICYCLE', 'Bicicleta', Icons.pedal_bike),
];

VehicleMeta vehicleMeta(String? type) => vehicleTypes.firstWhere((item) => item.type == type, orElse: () => vehicleTypes.first);

String paymentLabel(String? method) => method == 'ONLINE' ? 'En línea' : 'Efectivo';
