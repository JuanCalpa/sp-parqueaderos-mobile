import 'package:dio/dio.dart';
import '../config/env.dart';

/// Error legible para mostrar al usuario. Usa el { message } que devuelven los servicios y el gateway.
class ApiException implements Exception {
  final String message;
  final int? status;
  const ApiException(this.message, [this.status]);

  factory ApiException.from(Object error, String fallback) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final response = error.response;
      if (response == null) {
        return const ApiException('No hay conexión con el servidor (${Env.apiBaseUrl}). Verifica que el API Gateway esté encendido.');
      }
      final data = response.data;
      final message = data is Map && data['message'] is String && (data['message'] as String).isNotEmpty ? data['message'] as String : fallback;
      return ApiException(message, response.statusCode);
    }
    return ApiException(fallback);
  }

  @override
  String toString() => message;
}
