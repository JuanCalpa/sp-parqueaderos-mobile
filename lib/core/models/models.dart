// Espejo de los DTOs del backend (mismos que usa la web en front-parking-sp/src/app/core/models).

double _num(dynamic value) => value is num ? value.toDouble() : double.tryParse('${value ?? ''}') ?? 0;
int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;
DateTime? _date(dynamic value) => value == null ? null : DateTime.tryParse(value.toString());
List<String> _strings(dynamic value) => value is List ? value.map((item) => item.toString()).toList() : const [];

class SessionUser {
  final String uuid;
  final String fullName;
  final String email;
  final bool mustChangePassword;
  const SessionUser({required this.uuid, required this.fullName, required this.email, this.mustChangePassword = false});

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
        uuid: '${json['uuid']}',
        fullName: '${json['fullName'] ?? ''}',
        email: '${json['email'] ?? ''}',
        mustChangePassword: json['mustChangePassword'] == true,
      );
  Map<String, dynamic> toJson() => {'uuid': uuid, 'fullName': fullName, 'email': email, 'mustChangePassword': mustChangePassword};
}

class TenantAccess {
  final String uuid;
  final String name;
  /// OWNER, ADMIN o CASHIER.
  final String role;
  const TenantAccess({required this.uuid, required this.name, required this.role});

  factory TenantAccess.fromJson(Map<String, dynamic> json) =>
      TenantAccess(uuid: '${json['uuid']}', name: '${json['name'] ?? ''}', role: '${json['role'] ?? 'CASHIER'}');
  Map<String, dynamic> toJson() => {'uuid': uuid, 'name': name, 'role': role};

  String get roleLabel => const {'OWNER': 'Propietario', 'ADMIN': 'Administrador', 'CASHIER': 'Cajero'}[role] ?? 'Usuario';
  bool get canManage => role == 'OWNER' || role == 'ADMIN';
}

class Session {
  final String token;
  final DateTime expiresAt;
  final SessionUser user;
  final List<TenantAccess> tenants;
  const Session({required this.token, required this.expiresAt, required this.user, required this.tenants});

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        token: '${json['token']}',
        expiresAt: _date(json['expiresAt']) ?? DateTime.now(),
        user: SessionUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
        tenants: ((json['tenants'] as List?) ?? const []).map((item) => TenantAccess.fromJson(Map<String, dynamic>.from(item as Map))).toList(),
      );
  Map<String, dynamic> toJson() => {
        'token': token,
        'expiresAt': expiresAt.toIso8601String(),
        'user': user.toJson(),
        'tenants': tenants.map((item) => item.toJson()).toList(),
      };

  bool get expired => !expiresAt.isAfter(DateTime.now());
  Session copyWith({SessionUser? user, List<TenantAccess>? tenants}) =>
      Session(token: token, expiresAt: expiresAt, user: user ?? this.user, tenants: tenants ?? this.tenants);
}

class Ticket {
  final String uuid;
  final String plate;
  final String vehicleType;
  final String? spaceCode;
  final String? keySlotCode;
  final List<String> helmetLockerCodes;
  final bool monthlySubscription;
  final DateTime checkedInAt;
  final DateTime? checkedOutAt;
  final String status;
  final double? amountDue;
  final String? paymentMethod;
  final String? code;
  final String? driverName;
  /// Descuento en pesos aplicado al cobrar la salida (amountDue ya lo tiene restado).
  final double? discountAmount;

  const Ticket({
    required this.uuid,
    required this.plate,
    required this.vehicleType,
    this.spaceCode,
    this.keySlotCode,
    this.helmetLockerCodes = const [],
    this.monthlySubscription = false,
    required this.checkedInAt,
    this.checkedOutAt,
    required this.status,
    this.amountDue,
    this.paymentMethod,
    this.code,
    this.driverName,
    this.discountAmount,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    final helmets = _strings(json['helmetLockerCodes']);
    final single = json['helmetLockerCode'];
    return Ticket(
      uuid: '${json['uuid']}',
      plate: '${json['plate'] ?? ''}',
      vehicleType: '${json['vehicleType'] ?? 'CAR'}',
      spaceCode: _blank(json['spaceCode']),
      keySlotCode: _blank(json['keySlotCode']),
      helmetLockerCodes: helmets.isNotEmpty ? helmets : (single == null || '$single'.isEmpty ? const [] : ['$single']),
      monthlySubscription: json['monthlySubscription'] == true,
      checkedInAt: _date(json['checkedInAt']) ?? DateTime.now(),
      checkedOutAt: _date(json['checkedOutAt']),
      status: '${json['status'] ?? ''}',
      amountDue: json['amountDue'] == null ? null : _num(json['amountDue']),
      paymentMethod: _blank(json['paymentMethod']),
      code: _blank(json['code']),
      driverName: _blank(json['driverName']),
      discountAmount: json['discountAmount'] == null ? null : _num(json['discountAmount']),
    );
  }

  Duration get elapsed => (checkedOutAt ?? DateTime.now()).difference(checkedInAt);
}

String? _blank(dynamic value) => value == null || '$value'.trim().isEmpty ? null : '$value';

class WhatsappStatus {
  final bool sent;
  final String? error;
  const WhatsappStatus({required this.sent, this.error});
  factory WhatsappStatus.fromJson(Map<String, dynamic> json) => WhatsappStatus(sent: json['sent'] == true, error: _blank(json['error']));
}

class CheckInResult {
  final Ticket ticket;
  final WhatsappStatus? whatsapp;
  const CheckInResult(this.ticket, this.whatsapp);
}

class Resource {
  final String code;
  final String kind;
  final bool occupied;
  final bool reserved;
  final String? assignedPlate;
  const Resource({required this.code, required this.kind, required this.occupied, required this.reserved, this.assignedPlate});

  factory Resource.fromJson(Map<String, dynamic> json) => Resource(
        code: '${json['code']}',
        kind: '${json['kind'] ?? ''}',
        occupied: json['occupied'] == true,
        reserved: json['reserved'] == true,
        assignedPlate: _blank(json['assignedPlate']),
      );

  bool get taken => occupied || reserved;
}

class ResourceBoard {
  final List<Resource> carSpaces;
  final List<Resource> motorcycleSpaces;
  final List<Resource> keySlots;
  final List<Resource> helmetLockers;
  const ResourceBoard({this.carSpaces = const [], this.motorcycleSpaces = const [], this.keySlots = const [], this.helmetLockers = const []});

  factory ResourceBoard.fromJson(Map<String, dynamic> json) {
    List<Resource> list(String key) {
      final items = ((json[key] as List?) ?? const []).map((item) => Resource.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      items.sort((a, b) => a.code.compareTo(b.code));
      return items;
    }

    return ResourceBoard(
      carSpaces: list('carSpaces'),
      motorcycleSpaces: list('motorcycleSpaces'),
      keySlots: list('keySlots'),
      helmetLockers: list('helmetLockers'),
    );
  }
}

class DashboardSummary {
  final int activeTickets;
  final int occupiedSpaces;
  final int availableSpaces;
  final int carOccupiedSpaces;
  final int carAvailableSpaces;
  final int motorcycleOccupiedSpaces;
  final int motorcycleAvailableSpaces;
  const DashboardSummary({
    this.activeTickets = 0,
    this.occupiedSpaces = 0,
    this.availableSpaces = 0,
    this.carOccupiedSpaces = 0,
    this.carAvailableSpaces = 0,
    this.motorcycleOccupiedSpaces = 0,
    this.motorcycleAvailableSpaces = 0,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
        activeTickets: _int(json['activeTickets']),
        occupiedSpaces: _int(json['occupiedSpaces']),
        availableSpaces: _int(json['availableSpaces']),
        carOccupiedSpaces: _int(json['carOccupiedSpaces']),
        carAvailableSpaces: _int(json['carAvailableSpaces']),
        motorcycleOccupiedSpaces: _int(json['motorcycleOccupiedSpaces']),
        motorcycleAvailableSpaces: _int(json['motorcycleAvailableSpaces']),
      );

  int get totalSpaces => occupiedSpaces + availableSpaces;
}

class TodayCash {
  final double todayRevenue;
  final double cashRevenue;
  final double onlineRevenue;
  final int payments;
  final double yesterdayRevenue;
  const TodayCash({this.todayRevenue = 0, this.cashRevenue = 0, this.onlineRevenue = 0, this.payments = 0, this.yesterdayRevenue = 0});

  factory TodayCash.fromJson(Map<String, dynamic> json) => TodayCash(
        todayRevenue: _num(json['todayRevenue']),
        cashRevenue: _num(json['cashRevenue']),
        onlineRevenue: _num(json['onlineRevenue']),
        payments: _int(json['payments']),
        yesterdayRevenue: _num(json['yesterdayRevenue']),
      );
}

class PricingCalculation {
  final int billableMinutes;
  final double total;
  final int days;
  final bool firstHourCharged;
  final int additionalMinutes;
  final double additionalAmount;
  const PricingCalculation({
    required this.billableMinutes,
    required this.total,
    required this.days,
    required this.firstHourCharged,
    required this.additionalMinutes,
    required this.additionalAmount,
  });

  factory PricingCalculation.fromJson(Map<String, dynamic> json) => PricingCalculation(
        billableMinutes: _int(json['billableMinutes']),
        total: _num(json['total']),
        days: _int(json['days']),
        firstHourCharged: json['firstHourCharged'] == true,
        additionalMinutes: _int(json['additionalMinutes']),
        additionalAmount: _num(json['additionalAmount']),
      );
}

double? _optNum(dynamic value) => value == null || '$value'.isEmpty ? null : _num(value);

/// Tarifa por tipo de vehiculo (pricing-service). PROGRESSIVE = primera hora + hora adicional proporcional; FLAT = valor fijo.
class PricingRule {
  final String vehicleType;
  final String displayName;
  final String pricingModel;
  final double? flatAmount;
  final double? hourlyAmount;
  final double? additionalHourAmount;
  final double? dayAmount;
  final bool applyDailyCap;
  final double? rateIncreaseAfterHours;
  final double? rateIncreaseAmount;
  final double? lostTicketFee;
  final bool active;
  const PricingRule({
    required this.vehicleType,
    required this.displayName,
    required this.pricingModel,
    this.flatAmount,
    this.hourlyAmount,
    this.additionalHourAmount,
    this.dayAmount,
    this.applyDailyCap = false,
    this.rateIncreaseAfterHours,
    this.rateIncreaseAmount,
    this.lostTicketFee,
    this.active = true,
  });

  factory PricingRule.fromJson(Map<String, dynamic> json) => PricingRule(
        vehicleType: '${json['vehicleType']}',
        displayName: '${json['displayName'] ?? json['vehicleType']}',
        pricingModel: '${json['pricingModel'] ?? 'PROGRESSIVE'}',
        flatAmount: _optNum(json['flatAmount']),
        hourlyAmount: _optNum(json['hourlyAmount']),
        additionalHourAmount: _optNum(json['additionalHourAmount']),
        dayAmount: _optNum(json['dayAmount']),
        applyDailyCap: json['applyDailyCap'] == true,
        rateIncreaseAfterHours: _optNum(json['rateIncreaseAfterHours']),
        rateIncreaseAmount: _optNum(json['rateIncreaseAmount']),
        lostTicketFee: _optNum(json['lostTicketFee']),
        active: json['active'] != false,
      );

  /// Mismo cuerpo que envia la web al guardar (PUT /pricing/rules/{vehicleType}).
  Map<String, dynamic> toJson() => {
        'vehicleType': vehicleType,
        'displayName': displayName,
        'pricingModel': pricingModel,
        'flatAmount': flatAmount,
        'hourlyAmount': hourlyAmount,
        'additionalHourAmount': additionalHourAmount ?? hourlyAmount,
        'dayAmount': dayAmount,
        'applyDailyCap': applyDailyCap,
        'rateIncreaseAfterHours': rateIncreaseAfterHours,
        'rateIncreaseAmount': rateIncreaseAmount,
        'lostTicketFee': lostTicketFee,
        'active': active,
      };

  bool get flat => pricingModel == 'FLAT';
  double get additional => additionalHourAmount ?? hourlyAmount ?? 0;

  /// Estimacion del cobro para N minutos, con la misma formula que la web (core/utils estimateCharge)
  /// y que pricing-service: primera hora completa, minutos adicionales proporcionales, dias y tope diario.
  double estimate(int minutes) {
    if (flat) return flatAmount ?? 0;
    final billable = minutes < 1 ? 1 : minutes;
    final day = dayAmount ?? 0;
    var days = 0;
    var rest = billable;
    if (billable >= 1440 && day > 0) {
      days = billable ~/ 1440;
      rest = billable % 1440;
      if (rest == 0) return day * days;
    }
    final increaseAfter = rateIncreaseAfterHours ?? 0;
    final increase = rateIncreaseAmount ?? 0;
    double withIncrease(int hour, double base) => increaseAfter > 0 && hour > increaseAfter ? base + increase : base;
    final additionalMinutes = rest - 60 < 0 ? 0 : rest - 60;
    final fullHours = additionalMinutes ~/ 60;
    final loose = additionalMinutes % 60;
    var additionalAmount = 0.0;
    for (var hour = 2; hour <= fullHours + 1; hour++) {
      additionalAmount += withIncrease(hour, additional);
    }
    if (loose > 0) additionalAmount += withIncrease(fullHours + 2, additional) * loose / 60;
    var hours = withIncrease(1, hourlyAmount ?? 0) + additionalAmount.roundToDouble();
    if (applyDailyCap && day > 0 && hours > day) hours = day;
    return day * days + hours;
  }
}

/// Registro de auditoria (quien hizo que y cuando).
class AuditEntry {
  final int id;
  final DateTime? createdAt;
  final String? actor;
  final String action;
  final String? entityType;
  final String? entityRef;
  final String? details;
  final String? source;
  const AuditEntry({required this.id, this.createdAt, this.actor, required this.action, this.entityType, this.entityRef, this.details, this.source});

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        id: _int(json['id']),
        createdAt: _date(json['createdAt']),
        actor: _blank(json['actor']),
        action: '${json['action'] ?? ''}',
        entityType: _blank(json['entityType']),
        entityRef: _blank(json['entityRef']),
        details: _blank(json['details']),
        source: _blank(json['source']),
      );
}

class AuditPage {
  final List<AuditEntry> entries;
  /// true si el servidor corto el resultado (maximo 500 registros).
  final bool truncated;
  final List<String> actors;
  const AuditPage({this.entries = const [], this.truncated = false, this.actors = const []});

  factory AuditPage.fromJson(Map<String, dynamic> json) => AuditPage(
        entries: ((json['entries'] as List?) ?? const []).map((item) => AuditEntry.fromJson(Map<String, dynamic>.from(item as Map))).toList(),
        truncated: json['truncated'] == true,
        actors: _strings(json['actors']),
      );
}

class MonthlySubscription {
  final String uuid;
  final String customerName;
  final String? customerPhone;
  final String plate;
  final String vehicleType;
  final double amount;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  /// ACTIVE, EXPIRED o CANCELLED.
  final String status;
  final DateTime? reminderSentAt;
  const MonthlySubscription({
    required this.uuid,
    required this.customerName,
    this.customerPhone,
    required this.plate,
    required this.vehicleType,
    required this.amount,
    this.startsAt,
    this.expiresAt,
    required this.status,
    this.reminderSentAt,
  });

  factory MonthlySubscription.fromJson(Map<String, dynamic> json) => MonthlySubscription(
        uuid: '${json['uuid']}',
        customerName: '${json['customerName'] ?? ''}',
        customerPhone: _blank(json['customerPhone']),
        plate: '${json['plate'] ?? ''}',
        vehicleType: '${json['vehicleType'] ?? 'CAR'}',
        amount: _num(json['amount']),
        startsAt: _date(json['startsAt']),
        expiresAt: _date(json['expiresAt']),
        status: '${json['status'] ?? (json['active'] == true ? 'ACTIVE' : 'EXPIRED')}',
        reminderSentAt: _date(json['reminderSentAt']),
      );

  bool get active => status == 'ACTIVE';

  /// Dias que faltan para el vencimiento (0 = vence hoy).
  int get daysLeft {
    if (expiresAt == null) return 0;
    final now = DateTime.now();
    return DateTime(expiresAt!.year, expiresAt!.month, expiresAt!.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  }
}

class CashPayment {
  final String uuid;
  final String concept;
  final double amount;
  final String method;
  final String? plate;
  final String? vehicleType;
  final String? description;
  final DateTime? paidAt;
  const CashPayment({required this.uuid, required this.concept, required this.amount, required this.method, this.plate, this.vehicleType, this.description, this.paidAt});

  factory CashPayment.fromJson(Map<String, dynamic> json) => CashPayment(
        uuid: '${json['uuid']}',
        concept: '${json['concept'] ?? 'PARKING'}',
        amount: _num(json['amount']),
        method: '${json['method'] ?? 'CASH'}',
        plate: _blank(json['plate']),
        vehicleType: _blank(json['vehicleType']),
        description: _blank(json['description']),
        paidAt: _date(json['paidAt']),
      );
}

class CashTotals {
  final double cash;
  final double online;
  final double parking;
  final double monthly;
  final double total;
  final int payments;
  final int vehicles;
  const CashTotals({this.cash = 0, this.online = 0, this.parking = 0, this.monthly = 0, this.total = 0, this.payments = 0, this.vehicles = 0});

  factory CashTotals.fromJson(Map<String, dynamic>? json) => json == null
      ? const CashTotals()
      : CashTotals(
          cash: _num(json['cash']),
          online: _num(json['online']),
          parking: _num(json['parking']),
          monthly: _num(json['monthly']),
          total: _num(json['total']),
          payments: _int(json['payments']),
          vehicles: _int(json['vehicles']),
        );
}

class CashSession {
  final String uuid;
  final String status;
  final DateTime? openedAt;
  final String? openedByName;
  final double openingFloat;
  final CashTotals totals;
  final double expectedCash;
  final List<CashPayment> payments;
  const CashSession({
    required this.uuid,
    required this.status,
    this.openedAt,
    this.openedByName,
    required this.openingFloat,
    required this.totals,
    required this.expectedCash,
    this.payments = const [],
  });

  factory CashSession.fromJson(Map<String, dynamic> json) => CashSession(
        uuid: '${json['uuid']}',
        status: '${json['status'] ?? 'OPEN'}',
        openedAt: _date(json['openedAt']),
        openedByName: _blank(json['openedByName']),
        openingFloat: _num(json['openingFloat']),
        totals: CashTotals.fromJson(json['totals'] == null ? null : Map<String, dynamic>.from(json['totals'] as Map)),
        expectedCash: _num(json['expectedCash']),
        payments: ((json['payments'] as List?) ?? const []).map((item) => CashPayment.fromJson(Map<String, dynamic>.from(item as Map))).toList(),
      );
}

class Branch {
  final String uuid;
  final String name;
  final String? address;
  final bool manageResources;
  const Branch({required this.uuid, required this.name, this.address, this.manageResources = true});

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
        uuid: '${json['uuid']}',
        name: '${json['name'] ?? ''}',
        address: _blank(json['address']),
        manageResources: json['manageResources'] != false,
      );
}
