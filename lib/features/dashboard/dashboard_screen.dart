import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/parking_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Branch? _branch;
  DashboardSummary? _summary;
  TodayCash? _cash;
  ResourceBoard? _board;
  List<Ticket> _active = const [];
  List<Ticket> _week = const [];
  List<MonthlySubscription> _monthly = const [];
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Cada bloque se carga por separado: si un servicio falla, el resto del tablero se sigue viendo.
  Future<void> _load() async {
    final api = ref.read(parkingApiProvider);
    final now = DateTime.now();
    String? firstError;
    Future<Object?> safe(Future<Object?> request) async {
      try {
        return await request;
      } catch (error) {
        firstError ??= error.toString();
        return null;
      }
    }

    final results = await Future.wait<Object?>([
      safe(api.currentBranch()),
      safe(api.dashboard()),
      safe(api.todayCash()),
      safe(api.resourceBoard()),
      safe(api.activeTickets()),
      safe(api.ticketHistory(now.subtract(const Duration(days: 6)), now)),
      safe(api.monthlySubscriptions()),
    ]);
    if (!mounted) return;
    setState(() {
      _branch = results[0] as Branch?;
      _summary = results[1] as DashboardSummary?;
      _cash = results[2] as TodayCash?;
      _board = results[3] as ResourceBoard?;
      _active = (results[4] as List<Ticket>?) ?? const [];
      _week = (results[5] as List<Ticket>?) ?? const [];
      _monthly = (results[6] as List<MonthlySubscription>?) ?? const [];
      _error = results.every((item) => item == null) ? firstError : null;
      _loading = false;
    });
  }

  bool _isToday(DateTime? value) {
    if (value == null) return false;
    final local = value.toLocal();
    final now = DateTime.now();
    return local.year == now.year && local.month == now.month && local.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    final auth = ref.watch(authProvider);
    final summary = _summary ?? const DashboardSummary();
    final cash = _cash ?? const TodayCash();
    final occupancy = summary.totalSpaces == 0 ? 0.0 : summary.occupiedSpaces / summary.totalSpaces;
    final entriesToday = _week.where((item) => _isToday(item.checkedInAt)).length;
    final exitsToday = _week.where((item) => _isToday(item.checkedOutAt)).length;
    final activeMonthly = _monthly.where((item) => item.active).toList();
    final expiring = activeMonthly.where((item) => item.daysLeft <= 5).length;
    final change = cash.yesterdayRevenue > 0 ? ((cash.todayRevenue - cash.yesterdayRevenue) / cash.yesterdayRevenue * 100).round() : null;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          if (_error != null) ...[ErrorPanel(_error!, onRetry: _load), const SizedBox(height: 12)],
          SpCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: const Icon(Icons.storefront_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_branch?.name ?? auth.tenant?.name ?? 'Parqueadero', style: AppText.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (_branch?.address != null) Text(_branch!.address!, style: AppText.mono(size: 11, weight: FontWeight.w500, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              const StatusChip('Activo', dot: true),
            ]),
          ),
          const SizedBox(height: 12),
          PrimaryButton(label: 'NUEVA ENTRADA', icon: Icons.bolt, large: true, onPressed: () => context.go('/entrada')),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: KpiCard(
                label: 'Vehículos adentro',
                value: '${summary.activeTickets}',
                suffix: summary.totalSpaces > 0 ? '/ ${summary.totalSpaces}' : null,
                icon: Icons.directions_car_filled_outlined,
                footer: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ProgressRail(occupancy),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: Text('${(occupancy * 100).round()}% ocupado', style: AppText.mono(size: 10.5, weight: FontWeight.w500, color: AppColors.textMuted))),
                    Text('${summary.availableSpaces} libres', style: AppText.mono(size: 10.5, color: AppColors.green)),
                  ]),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KpiCard(
                label: 'Ingresos hoy',
                value: money(cash.todayRevenue),
                valueColor: AppColors.green,
                icon: Icons.payments_outlined,
                iconColor: AppColors.green,
                footer: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (change != null)
                    Text('${change >= 0 ? '↑' : '↓'} ${change.abs()}% vs ayer', style: AppText.mono(size: 11, color: change >= 0 ? AppColors.green : AppColors.primary)),
                  Text('${cash.payments} pagos reg.', style: AppText.mono(size: 10.5, weight: FontWeight.w500, color: AppColors.textMuted)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: KpiCard(
                label: 'Movimientos',
                value: '${entriesToday + exitsToday}',
                icon: Icons.swap_vert,
                iconColor: AppColors.amber,
                footer: Text('↓ $entriesToday ent  ↑ $exitsToday sal', style: AppText.mono(size: 11, color: AppColors.green)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KpiCard(
                label: 'Mensualidades',
                value: '${activeMonthly.length}',
                suffix: 'activas',
                icon: Icons.badge_outlined,
                iconColor: AppColors.blue,
                footer: Text(expiring > 0 ? '• $expiring por vencer' : 'Ninguna por vencer', style: AppText.mono(size: 11, color: expiring > 0 ? AppColors.amber : AppColors.textMuted)),
              ),
            ),
          ]),
          if (_board != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              _MiniStat('Carros', Icons.directions_car_filled_outlined, '${summary.carOccupiedSpaces}', '/${summary.carOccupiedSpaces + summary.carAvailableSpaces}'),
              _MiniStat('Motos', Icons.two_wheeler, '${summary.motorcycleOccupiedSpaces}', '/${summary.motorcycleOccupiedSpaces + summary.motorcycleAvailableSpaces}'),
              _MiniStat('Llaves', Icons.key_outlined, '${_board!.keySlots.where((item) => item.occupied).length}', ' uso', color: AppColors.amber),
              _MiniStat('Cascos', Icons.sports_motorsports_outlined, '${_board!.helmetLockers.where((item) => item.occupied).length}', ' uso', color: AppColors.green),
            ]),
            const SizedBox(height: 18),
            SpCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionTitle('Mapa de ocupación', trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  _Legend('Libre', AppColors.green),
                  SizedBox(width: 8),
                  _Legend('Ocupado', AppColors.primary),
                ])),
                if (_board!.carSpaces.isNotEmpty) ...[
                  Text('Zona Carros (${_board!.carSpaces.length})', style: AppText.mono(size: 11, weight: FontWeight.w500, color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  _SlotGrid(_board!.carSpaces),
                  const SizedBox(height: 14),
                ],
                if (_board!.motorcycleSpaces.isNotEmpty) ...[
                  Text('Zona Motos (${_board!.motorcycleSpaces.length})', style: AppText.mono(size: 11, weight: FontWeight.w500, color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  _SlotGrid(_board!.motorcycleSpaces),
                ],
                if (_board!.carSpaces.isEmpty && _board!.motorcycleSpaces.isEmpty)
                  Text('Este parqueadero no tiene espacios configurados.', style: AppText.small),
              ]),
            ),
          ],
          const SizedBox(height: 18),
          SectionTitle('Vehículos adentro', trailing: Text('${_active.length} activos', style: AppText.mono(size: 12, weight: FontWeight.w600, color: AppColors.textMuted))),
          if (_active.isEmpty)
            SpCard(child: Text('No hay vehículos adentro en este momento.', style: AppText.sans(color: AppColors.textMuted))),
          for (final ticket in _active) Padding(padding: const EdgeInsets.only(bottom: 10), child: _ActiveTicketCard(ticket)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final String suffix;
  final Color color;
  const _MiniStat(this.label, this.icon, this.value, this.suffix, {this.color = AppColors.text});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: SpCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: AppText.mono(size: 10, weight: FontWeight.w500, color: AppColors.textMuted))),
            ]),
            const SizedBox(height: 4),
            Text.rich(TextSpan(children: [
              TextSpan(text: value, style: AppText.mono(size: 15, weight: FontWeight.w800, color: color)),
              TextSpan(text: suffix, style: AppText.mono(size: 10, weight: FontWeight.w500, color: AppColors.textMuted)),
            ])),
          ]),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String text;
  final Color color;
  const _Legend(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(text.toUpperCase(), style: AppText.mono(size: 9.5, color: color)),
    ]);
  }
}

/// Celdas de espacios: verde libre, rojo ocupado (con la placa), ambar reservado por mensualidad.
class _SlotGrid extends StatelessWidget {
  final List<Resource> slots;
  const _SlotGrid(this.slots);

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 1.05,
      children: [
        for (final slot in slots)
          InkWell(
            onTap: slot.occupied && slot.assignedPlate != null ? () => context.go('/salidas?placa=${slot.assignedPlate}') : null,
            child: Container(
              decoration: BoxDecoration(
                color: slot.occupied ? AppColors.primaryLight : (slot.reserved ? AppColors.amberLight : AppColors.greenLight),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: slot.occupied ? AppColors.primary : (slot.reserved ? AppColors.amberBorder : AppColors.greenBorder),
                  width: slot.occupied ? 1.5 : 1,
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(slot.code, style: AppText.mono(size: 11.5, weight: FontWeight.w800, color: slot.occupied ? AppColors.primary : (slot.reserved ? AppColors.amber : AppColors.green))),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    slot.occupied ? displayPlate(slot.assignedPlate) : (slot.reserved ? 'RESERV.' : 'LIBRE'),
                    style: AppText.mono(size: 8.5, weight: FontWeight.w600, color: slot.occupied ? AppColors.primaryDark : AppColors.textMuted),
                  ),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

class _ActiveTicketCard extends StatelessWidget {
  final Ticket ticket;
  const _ActiveTicketCard(this.ticket);

  @override
  Widget build(BuildContext context) {
    final meta = vehicleMeta(ticket.vehicleType);
    final custody = [
      if (ticket.keySlotCode != null) '${ticket.keySlotCode} Llave',
      ...ticket.helmetLockerCodes.map((code) => '$code Casco'),
    ];
    return SpCard(
      borderColor: ticket.monthlySubscription ? AppColors.blueBorder : AppColors.border,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PlateBadge(ticket.plate, monthly: ticket.monthlySubscription),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(meta.icon, size: 16, color: AppColors.blue),
                const SizedBox(width: 4),
                Text(ticket.monthlySubscription ? '${meta.label} (Mensual)' : meta.label, style: AppText.sans(size: 13, weight: FontWeight.w700)),
              ]),
              Text('Slot: ${ticket.spaceCode ?? '—'}', style: AppText.mono(size: 11.5, weight: FontWeight.w500, color: AppColors.textMuted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            ticket.monthlySubscription ? const StatusChip.blue('Mensualidad') : const StatusChip('Adentro'),
            const SizedBox(height: 4),
            Text('Entrada: ${hhmm(ticket.checkedInAt)}', style: AppText.mono(size: 11.5, weight: FontWeight.w500, color: AppColors.textMuted)),
          ]),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('CASILLEROS', style: AppText.meta),
                const SizedBox(height: 2),
                Text(custody.isEmpty ? '—' : custody.join(' · '), style: AppText.mono(size: 12.5, color: AppColors.green)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('TIEMPO', style: AppText.meta),
              const SizedBox(height: 2),
              Text(duration(ticket.elapsed), style: AppText.mono(size: 14, weight: FontWeight.w800)),
            ]),
          ]),
        ),
        if (!ticket.monthlySubscription) ...[
          const SizedBox(height: 12),
          PrimaryButton(label: 'Cobrar / Salida', icon: Icons.payments_outlined, onPressed: () => context.go('/salidas?placa=${ticket.plate}')),
        ] else ...[
          const SizedBox(height: 12),
          GhostButton(label: 'Dar salida', icon: Icons.logout, onPressed: () => context.go('/salidas?placa=${ticket.plate}')),
        ],
      ]),
    );
  }
}
