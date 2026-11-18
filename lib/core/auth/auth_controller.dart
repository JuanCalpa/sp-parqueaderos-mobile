import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_exception.dart';
import '../config/env.dart';
import '../models/models.dart';

final authProvider = ChangeNotifierProvider<AuthController>((ref) => AuthController());

/// Sesion del usuario (mismo login que la web). El token se guarda cifrado en el dispositivo.
class AuthController extends ChangeNotifier {
  static const _sessionKey = 'sp_session';
  static const _tenantKey = 'sp_tenant';

  final _storage = const FlutterSecureStorage();
  final _dio = Dio(BaseOptions(baseUrl: Env.tenantApi, connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 20)));

  Session? _session;
  String? _tenantUuid;
  bool _ready = false;
  bool _expiredNotice = false;

  Session? get session => _session;
  bool get ready => _ready;
  bool get loggedIn => _session != null;
  String? get token => _session?.token;
  SessionUser? get user => _session?.user;
  List<TenantAccess> get tenants => _session?.tenants ?? const [];
  String? get tenantUuid => _tenantUuid;
  TenantAccess? get tenant => tenants.where((item) => item.uuid == _tenantUuid).firstOrNull;

  /// true una sola vez despues de que el servidor rechazo la sesion (para avisar en el login).
  bool takeExpiredNotice() {
    final value = _expiredNotice;
    _expiredNotice = false;
    return value;
  }

  /// Restaura la sesion guardada y la valida con el servidor.
  Future<void> init() async {
    try {
      final raw = await _storage.read(key: _sessionKey);
      if (raw != null) {
        final stored = Session.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
        if (!stored.expired) {
          _session = stored;
          _tenantUuid = await _storage.read(key: _tenantKey);
          await _refresh();
        }
      }
    } catch (_) {
      await _clear();
    }
    _pickTenantIfSingle();
    _ready = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/auth/login', data: {'email': email.trim(), 'password': password});
      await _store(Session.fromJson(response.data!));
    } catch (error) {
      throw ApiException.from(error, 'No se pudo iniciar sesión');
    }
  }

  /// Crea el usuario y su propio parqueadero, del que queda como propietario.
  Future<void> register({required String fullName, required String email, required String password, required String parkingName, String? branchAddress}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/auth/register', data: {
        'fullName': fullName.trim(),
        'email': email.trim(),
        'password': password,
        'parkingName': parkingName.trim(),
        'branchAddress': (branchAddress ?? '').trim().isEmpty ? null : branchAddress!.trim(),
      });
      await _store(Session.fromJson(response.data!));
    } catch (error) {
      throw ApiException.from(error, 'No se pudo crear la cuenta');
    }
  }

  Future<void> selectTenant(String uuid) async {
    _tenantUuid = uuid;
    await _storage.write(key: _tenantKey, value: uuid);
    notifyListeners();
  }

  Future<void> logout() async {
    final current = token;
    await _clear();
    notifyListeners();
    if (current != null) {
      _dio.post<void>('/auth/logout', options: Options(headers: {'Authorization': 'Bearer $current'})).ignore();
    }
  }

  /// El servidor rechazo el token (401): se cierra la sesion local.
  Future<void> expire() async {
    if (_session == null) return;
    _expiredNotice = true;
    await _clear();
    notifyListeners();
  }

  Future<void> _refresh() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me', options: Options(headers: {'Authorization': 'Bearer ${_session!.token}'}));
      final data = response.data!;
      final tenants = ((data['tenants'] as List?) ?? const []).map((item) => TenantAccess.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      await _store(_session!.copyWith(user: SessionUser.fromJson(Map<String, dynamic>.from(data['user'] as Map)), tenants: tenants), notify: false);
    } on DioException catch (error) {
      // Sin conexion se conserva la sesion guardada; si el servidor la rechaza, se cierra.
      if (error.response?.statusCode == 401) await _clear();
    }
  }

  Future<void> _store(Session session, {bool notify = true}) async {
    _session = session;
    if (_tenantUuid != null && !session.tenants.any((item) => item.uuid == _tenantUuid)) _tenantUuid = null;
    _pickTenantIfSingle();
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
    if (_tenantUuid != null) await _storage.write(key: _tenantKey, value: _tenantUuid);
    if (notify) notifyListeners();
  }

  void _pickTenantIfSingle() {
    if (_tenantUuid == null && tenants.length == 1) _tenantUuid = tenants.first.uuid;
  }

  Future<void> _clear() async {
    _session = null;
    _tenantUuid = null;
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _tenantKey);
  }
}
