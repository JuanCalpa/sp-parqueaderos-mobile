import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_parking_sp/core/models/models.dart';
import 'package:mobile_parking_sp/core/utils/format.dart';

void main() {
  const rule = PricingRule(vehicleType: 'CAR', displayName: 'Carro', pricingModel: 'PROGRESSIVE', hourlyAmount: 3000, additionalHourAmount: 2000, dayAmount: 20000);

  test('primera hora completa aunque sea menos tiempo', () {
    expect(rule.estimate(45), 3000);
  });

  test('minutos adicionales proporcionales a la hora adicional', () {
    expect(rule.estimate(80), 3000 + 667); // 20 min de 2000/h
    expect(rule.estimate(150), 3000 + 3000); // 1 h 30 min adicionales
  });

  test('dias completos y tope diario', () {
    expect(rule.estimate(1440), 20000);
    const capped = PricingRule(vehicleType: 'CAR', displayName: 'Carro', pricingModel: 'PROGRESSIVE', hourlyAmount: 3000, additionalHourAmount: 2000, dayAmount: 10000, applyDailyCap: true);
    expect(capped.estimate(600), 10000);
  });

  test('tarifa plana ignora el tiempo', () {
    const flat = PricingRule(vehicleType: 'BICYCLE', displayName: 'Bici', pricingModel: 'FLAT', flatAmount: 1500);
    expect(flat.estimate(500), 1500);
  });

  test('valor por minuto con decimales', () {
    expect(moneyDecimal(2000 / 60), r'$33,33');
    expect(moneyDecimal(3000 / 60), r'$50');
  });
}
