import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';
import '../config/env.dart';
import '../models/models.dart';
import '../utils/format.dart';
import 'api_exception.dart';

final parkingApiProvider = Provider<ParkingApi>((ref) => ParkingApi(ref.read(authProvider)));

/// Catalogo de tipos de vehiculo del parqueadero activo. Se carga al entrar (y al cambiar de parqueadero)
/// para que todas las pantallas muestren los tipos agregados en Configuracion.
final vehicleCatalogProvider = FutureProvider<List<PricingRule>>((ref) {
  ref.watch(authProvider.select((auth) => auth.tenantUuid));
  return ref.read(parkingApiProvider).pricingRules();
});

/// Llamadas a los microservicios a traves del API Gateway. Agrega el token y el parqueadero activo
/// (X-Tenant-Id) a cada peticion, igual que el interceptor de la web.
class ParkingApi {
  final AuthController auth;
  late final Dio _dio;

  ParkingApi(this.auth) {
    _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 30)));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = auth.token;
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        final tenant = auth.tenantUuid;
        if (tenant != null) options.headers['X-Tenant-Id'] = tenant;
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) auth.expire();
        handler.next(error);
      },
    ));
  }

  Future<T> _call<T>(Future<Response<dynamic>> Function() request, T Function(dynamic data) parse, String fallback) async {
    try {
      final response = await request();
      return parse(response.data);
    } catch (error) {
      throw ApiException.from(error, fallback);
    }
  }

  static Map<String, dynamic> _map(dynamic data) => Map<String, dynamic>.from(data as Map);
  static List<Map<String, dynamic>> _list(dynamic data) => ((data as List?) ?? const []).map((item) => Map<String, dynamic>.from(item as Map)).toList();

  // ---------- Parqueadero ----------

  /// Primera sede del parqueadero activo (la que usa la operacion).
  Future<Branch?> currentBranch() => _call(() => _dio.get('${Env.tenantApi}/tenants'), (data) {
        final tenant = _list(data).where((item) => item['uuid'] == auth.tenantUuid).firstOrNull;
        final branches = tenant == null ? const <Map<String, dynamic>>[] : _list(tenant['branches']);
        return branches.isEmpty ? null : Branch.fromJson(branches.first);
      }, 'No se pudo cargar el parqueadero');

  // ---------- Operacion ----------

  Future<List<Ticket>> activeTickets() =>
      _call(() => _dio.get('${Env.operationApi}/tickets/active'), (data) => _list(data).map(Ticket.fromJson).toList(), 'No se pudieron cargar los vehículos adentro');

  Future<List<Ticket>> recentTickets() =>
      _call(() => _dio.get('${Env.operationApi}/tickets/recent'), (data) => _list(data).map(Ticket.fromJson).toList(), 'No se pudo cargar la actividad');

  /// Tickets cuya entrada cae entre from y to (fechas locales, inclusive).
  Future<List<Ticket>> ticketHistory(DateTime from, DateTime to) => _call(
        () => _dio.get('${Env.operationApi}/tickets/history', queryParameters: {'from': _day(from), 'to': _day(to)}),
        (data) => _list(data).map(Ticket.fromJson).toList(),
        'No se pudo cargar el historial',
      );

  static String _day(DateTime value) => '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<Ticket> ticketByPlate(String plate) =>
      _call(() => _dio.get('${Env.operationApi}/tickets/by-plate/$plate'), (data) => Ticket.fromJson(_map(data)), 'No se encontró un vehículo adentro con esa placa');

  Future<ResourceBoard> resourceBoard() =>
      _call(() => _dio.get('${Env.operationApi}/resources/board'), (data) => ResourceBoard.fromJson(_map(data)), 'No se pudo cargar el mapa de espacios');

  Future<CheckInResult> checkIn({
    required String plate,
    required String vehicleType,
    required String driverPhone,
    String? driverName,
    String? spaceCode,
    String? keySlotCode,
    List<String> helmetLockerCodes = const [],
    bool monthlySubscription = false,
    bool sendWhatsapp = true,
  }) =>
      _call(
        () => _dio.post('${Env.operationApi}/tickets/check-in', data: {
          'plate': plate,
          'vehicleType': vehicleType,
          'driverPhone': driverPhone,
          'driverName': (driverName ?? '').trim().isEmpty ? null : driverName!.trim(),
          'sendWhatsapp': sendWhatsapp,
          'spaceCode': spaceCode ?? '',
          'keySlotCode': keySlotCode ?? '',
          'helmetLockerCodes': helmetLockerCodes,
          'monthlySubscription': monthlySubscription,
        }),
        (data) {
          final json = _map(data);
          return CheckInResult(Ticket.fromJson(_map(json['ticket'])), json['whatsapp'] == null ? null : WhatsappStatus.fromJson(_map(json['whatsapp'])));
        },
        'No se pudo registrar la entrada',
      );

  /// El valor lo calcula el servidor; si el cobro no entra a caja, la salida se revierte.
  /// [discountAmount] es un monto exacto en pesos (no porcentaje); el servidor valida que no supere el total.
  Future<Ticket> checkOut(String ticketUuid, {required String paymentMethod, String? onlineReference, double discountAmount = 0, String? discountReason}) => _call(
        () => _dio.post('${Env.operationApi}/tickets/$ticketUuid/check-out', data: {
          'paymentMethod': paymentMethod,
          'onlineReference': paymentMethod == 'ONLINE' && (onlineReference ?? '').trim().isNotEmpty ? onlineReference!.trim() : null,
          'discountAmount': discountAmount > 0 ? discountAmount : null,
          'discountReason': discountAmount > 0 && (discountReason ?? '').trim().isNotEmpty ? discountReason!.trim() : null,
        }),
        (data) => Ticket.fromJson(_map(data)),
        'No se pudo registrar la salida del vehículo',
      );

  Future<WhatsappStatus> resendWhatsapp(String ticketUuid) => _call(() => _dio.post('${Env.operationApi}/tickets/$ticketUuid/whatsapp', data: {}),
      (data) => WhatsappStatus.fromJson(_map(data)), 'No se pudo enviar el ticket por WhatsApp');

  Future<List<MonthlySubscription>> monthlySubscriptions() => _call(() => _dio.get('${Env.operationApi}/monthly-subscriptions'),
      (data) => _list(data).map(MonthlySubscription.fromJson).toList(), 'No se pudieron cargar las mensualidades');

  // ---------- Tarifas ----------

  /// Tarifas y tipos de vehiculo activos. Tambien actualiza los tipos que muestra toda la app.
  Future<List<PricingRule>> pricingRules() => _call(() => _dio.get('${Env.pricingApi}/pricing/rules'), (data) {
        final rules = _list(_map(data)['rules']).map(PricingRule.fromJson).toList();
        registerVehicleTypes(rules.map((rule) => (rule.vehicleType, rule.displayName, rule.category)));
        return rules;
      }, 'No se pudieron cargar las tarifas');

  /// Solo propietario y administrador (el servidor responde 403 a un cajero).
  Future<PricingRule> savePricingRule(PricingRule rule) => _call(() => _dio.put('${Env.pricingApi}/pricing/rules/${rule.vehicleType}', data: rule.toJson()),
      (data) => PricingRule.fromJson(_map(data)), 'No se pudo guardar la tarifa');

  /// Agrega un tipo de vehiculo ("como carro" o "como moto") con su tarifa. Solo propietario y administrador.
  Future<PricingRule> createVehicleType(PricingRule draft) => _call(() => _dio.post('${Env.pricingApi}/pricing/rules', data: draft.toCreateJson()),
      (data) => PricingRule.fromJson(_map(data)), 'No se pudo agregar el tipo de vehículo');

  /// Elimina (desactiva) un tipo. El servidor lo rechaza si hay vehiculos adentro o mensualidades vigentes.
  Future<void> deleteVehicleType(String vehicleType) => _call(() => _dio.delete('${Env.pricingApi}/pricing/rules/$vehicleType'),
      (_) {}, 'No se pudo eliminar el tipo de vehículo');

  Future<PricingCalculation> calculate(Ticket ticket) => _call(
        () => _dio.post('${Env.pricingApi}/pricing/calculate', data: {
          'ticketUuid': ticket.uuid,
          'vehicleType': ticket.vehicleType,
          'checkedInAt': ticket.checkedInAt.toUtc().toIso8601String(),
        }),
        (data) => PricingCalculation.fromJson(_map(data)),
        'No se pudo calcular el cobro',
      );

  // ---------- Caja y reportes ----------

  Future<TodayCash> todayCash() => _call(() => _dio.get('${Env.paymentApi}/payments/today'), (data) => TodayCash.fromJson(_map(data)), 'No se pudo cargar la caja');

  Future<CashSession?> currentCashSession() => _call(() => _dio.get('${Env.paymentApi}/cash-sessions/current'), (data) {
        final session = _map(data)['session'];
        return session == null ? null : CashSession.fromJson(_map(session));
      }, 'No se pudo cargar la caja');

  Future<CashSession> openCash(double openingFloat) => _call(() => _dio.post('${Env.paymentApi}/cash-sessions/open', data: {'openingFloat': openingFloat}),
      (data) => CashSession.fromJson(_map(data)), 'No se pudo abrir la caja');

  Future<CashSession> closeCash(double countedCash, String? notes) => _call(
        () => _dio.post('${Env.paymentApi}/cash-sessions/current/close', data: {'countedCash': countedCash, 'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim()}),
        (data) => CashSession.fromJson(_map(data)),
        'No se pudo cerrar la caja',
      );

  /// Auditoria por rango de fechas (maximo 500 registros). Solo propietario y administrador.
  Future<AuditPage> audit({required DateTime from, required DateTime to, String? action, String? actor, String? query}) => _call(
        () => _dio.get('${Env.reportingApi}/audit', queryParameters: {
          'from': _day(from),
          'to': _day(to),
          if (action != null && action.isNotEmpty) 'action': action,
          if (actor != null && actor.isNotEmpty) 'actor': actor,
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        }),
        (data) => AuditPage.fromJson(_map(data)),
        'No se pudo consultar la auditoría',
      );

  Future<DashboardSummary> dashboard() =>
      _call(() => _dio.get('${Env.reportingApi}/dashboards/current'), (data) => DashboardSummary.fromJson(_map(data)), 'No se pudo cargar el resumen');
}
