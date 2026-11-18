import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_parking_sp/core/utils/format.dart';

void main() {
  test('money usa punto de miles y sin decimales', () {
    expect(money(0), r'$0');
    expect(money(2500), r'$2.500');
    expect(money(1234567.6), r'$1.234.568');
    expect(money(-6250), r'-$6.250');
  });

  test('placas se limpian y se muestran con espacio', () {
    expect(cleanPlate(' mye-79i '), 'MYE79I');
    expect(displayPlate('abc123'), 'ABC 123');
  });

  test('duracion en horas y minutos', () {
    expect(duration(const Duration(minutes: 150)), '2h 30m');
    expect(duration(const Duration(minutes: 9)), '9m');
  });

  test('cascos: moto hasta 2, bicicleta 1', () {
    expect(vehicleMeta('MOTORCYCLE').maxHelmets, 2);
    expect(vehicleMeta('BICYCLE').maxHelmets, 1);
    expect(vehicleMeta('CAR').compact, false);
  });
}

