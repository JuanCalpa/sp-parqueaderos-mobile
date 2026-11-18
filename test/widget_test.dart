// Reemplaza la prueba de ejemplo que genera `flutter create` (que referencia una app de contador que no existe).
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_parking_sp/core/models/models.dart';

void main() {
  test('el ticket toma helmetLockerCode cuando no viene la lista', () {
    final ticket = Ticket.fromJson({
      'uuid': 'u1',
      'plate': 'ABC123',
      'vehicleType': 'MOTORCYCLE',
      'helmetLockerCode': 'K02',
      'checkedInAt': '2026-11-10T13:00:00Z',
      'status': 'ACTIVE',
    });
    expect(ticket.helmetLockerCodes, ['K02']);
    expect(ticket.monthlySubscription, false);
  });
}
