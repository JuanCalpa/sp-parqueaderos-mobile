import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_parking_sp/core/utils/format.dart';

void main() {
  test('los tipos basicos conservan su comportamiento', () {
    expect(vehicleMeta('MOTORCYCLE').compact, true);
    expect(vehicleMeta('BICYCLE').maxHelmets, 1);
    expect(vehicleMeta('CAR').compact, false);
    expect(vehicleMeta('HEAVY').custom, false);
  });

  test('un tipo agregado "como moto" usa espacios de moto y hasta 2 cascos', () {
    registerVehicleTypes(const [('CAR', 'Carro Normal', 'CAR'), ('PATINETA', 'Patineta', 'MOTORCYCLE')]);
    final patineta = vehicleMeta('PATINETA');
    expect(patineta.label, 'Patineta');
    expect(patineta.compact, true);
    expect(patineta.maxHelmets, 2);
    expect(patineta.custom, true);
    // Solo quedan activos los del catalogo (Moto, Carga y Bicicleta fueron eliminados).
    expect(vehicleTypes.map((type) => type.type), ['CAR', 'PATINETA']);
  });

  test('un tipo que no esta en el catalogo muestra su nombre legible', () {
    expect(vehicleMeta('CAMIONETA_4X4').label, 'Camioneta 4x4');
  });
}
