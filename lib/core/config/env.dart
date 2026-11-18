/// Configuracion por ambiente. Se cambia al compilar, sin tocar codigo:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8090
class Env {
  /// URL del API Gateway. Por defecto el emulador de Android, donde 10.0.2.2 es el PC.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8090');

  static const tenantApi = '$apiBaseUrl/tenant/api';
  static const operationApi = '$apiBaseUrl/operation/api';
  static const pricingApi = '$apiBaseUrl/pricing/api';
  static const paymentApi = '$apiBaseUrl/payment/api';
  static const reportingApi = '$apiBaseUrl/reporting/api';
}
