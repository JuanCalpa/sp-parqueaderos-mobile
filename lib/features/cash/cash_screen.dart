import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/parking_api.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';

/// Caja del dia: apertura con base, recaudo por efectivo / en linea y cierre con arqueo.
class CashScreen extends ConsumerStatefulWidget {
  const CashScreen({super.key});

  @override
  ConsumerState<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends ConsumerState<CashScreen> {
  final _base = TextEditingController();
  CashSession? _session;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _base.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final session = await ref.read(parkingApiProvider).currentCashSession();
      if (mounted) {
        setState(() {
          _session = session;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _amount(String text) => double.tryParse(text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  Future<void> _open() async {
    setState(() => _busy = true);
    try {
      final session = await ref.read(parkingApiProvider).openCash(_amount(_base.text));
      if (!mounted) return;
      setState(() => _session = session);
      showMessage(context, 'Caja abierta con base de ${money(session.openingFloat)}');
      await _load();
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    final session = _session;
    if (session == null) return;
    final counted = TextEditingController();
    final notes = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          final difference = _amount(counted.text) - session.expectedCash;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Cierre de caja / arqueo'),
              AmountRow('Base inicial', money(session.openingFloat)),
              AmountRow('Cobrado en efectivo', money(session.totals.cash)),
              AmountRow('Efectivo esperado en gaveta', money(session.expectedCash), valueColor: AppColors.greenDark),
              const SizedBox(height: 12),
              const FieldLabel('Efectivo contado'),
              TextField(
                controller: counted,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setSheet(() {}),
                style: AppText.mono(size: 18),
                decoration: const InputDecoration(prefixText: '\$ ', hintText: '0'),
              ),
              if (counted.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                AmountRow(
                  difference == 0 ? 'Cuadra exacto' : (difference > 0 ? 'Sobrante' : 'Faltante'),
                  money(difference.abs()),
                  valueColor: difference == 0 ? AppColors.green : (difference > 0 ? AppColors.blue : AppColors.primary),
                ),
              ],
              const SizedBox(height: 10),
              const FieldLabel('Observaciones (opcional)'),
              TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(hintText: 'Novedades del turno')),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'CERRAR CAJA',
                icon: Icons.lock_outline,
                onPressed: counted.text.isEmpty ? null : () => Navigator.pop(context, true),
              ),
            ]),
          );
        },
      ),
    );
    // No se hace dispose aqui: la hoja aun puede estar animando su cierre con estos campos.
    final countedText = counted.text;
    final notesText = notes.text;
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final closed = await ref.read(parkingApiProvider).closeCash(_amount(countedText), notesText);
      if (!mounted) return;
      showMessage(context, 'Caja cerrada. Total del turno: ${money(closed.totals.total)}');
      await _load();
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          if (_error != null) ...[ErrorPanel(_error!, onRetry: _load), const SizedBox(height: 12)],
          if (_session == null && _error == null) _openForm() else if (_session != null) ..._sessionView(_session!),
        ],
      ),
    );
  }

  Widget _openForm() {
    return SpCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Caja del Día', style: AppText.display)),
          const StatusChip.muted('Cerrada', dot: true),
        ]),
        const SizedBox(height: 6),
        Text('Abre la caja para empezar el turno. La base es el efectivo con el que inicia la gaveta.', style: AppText.sans(color: AppColors.textMuted)),
        const SizedBox(height: 16),
        const FieldLabel('Base inicial'),
        TextField(
          controller: _base,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppText.mono(size: 18),
          decoration: const InputDecoration(prefixText: '\$ ', hintText: '0'),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'ABRIR CAJA', icon: Icons.lock_open_outlined, loading: _busy, onPressed: _open),
      ]),
    );
  }

  List<Widget> _sessionView(CashSession session) {
    final totals = session.totals;
    return [
      SpCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Caja del Día', style: AppText.display),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.badge_outlined, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Flexible(child: Text('Cajero: ${session.openedByName ?? '—'}', style: AppText.sans(color: AppColors.textSecondary))),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const StatusChip('Caja abierta', dot: true),
            const SizedBox(height: 6),
            Text('Desde ${hhmm(session.openedAt)}', style: AppText.mono(size: 11.5, weight: FontWeight.w500, color: AppColors.textMuted)),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      SpCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.amber, AppColors.green]),
            ),
          ),
          Text('TOTAL RECAUDADO DEL TURNO', style: AppText.meta),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(money(totals.total), style: AppText.sans(size: 36, weight: FontWeight.w800, letterSpacing: -1)))),
            const SizedBox(width: 6),
            Padding(padding: const EdgeInsets.only(bottom: 7), child: Text('COP', style: AppText.mono(size: 13, color: AppColors.textMuted))),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _MoneyBox('Base inicial', money(session.openingFloat), 'Apertura')),
            const SizedBox(width: 6),
            Expanded(child: _MoneyBox('En efectivo', money(totals.cash), 'En gaveta', color: AppColors.green, background: AppColors.greenLight, border: AppColors.greenBorder)),
            const SizedBox(width: 6),
            Expanded(child: _MoneyBox('En línea', money(totals.online), 'Transferencias', color: AppColors.blue, background: AppColors.blueLight, border: AppColors.blueBorder)),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      SectionTitle('Desglose por conceptos', trailing: Text('${totals.payments} operaciones', style: AppText.mono(size: 12, weight: FontWeight.w600, color: AppColors.textMuted))),
      Row(children: [
        Expanded(child: _ConceptCard('Tickets por tiempo', Icons.confirmation_number_outlined, money(totals.parking), '${totals.vehicles} vehículos')),
        const SizedBox(width: 10),
        Expanded(child: _ConceptCard('Mensualidades', Icons.calendar_month_outlined, money(totals.monthly), 'Ventas y renovaciones')),
      ]),
      const SizedBox(height: 16),
      const SectionTitle('Historial del turno', barColor: AppColors.green),
      if (session.payments.isEmpty) SpCard(child: Text('Aún no hay cobros en este turno.', style: AppText.sans(color: AppColors.textMuted))),
      for (final payment in session.payments.take(30)) Padding(padding: const EdgeInsets.only(bottom: 8), child: _PaymentRow(payment)),
      const SizedBox(height: 12),
      PrimaryButton(label: 'REALIZAR CIERRE DE CAJA / ARQUEO', icon: Icons.point_of_sale_outlined, large: true, loading: _busy, onPressed: _close),
    ];
  }
}

class _MoneyBox extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final Color color;
  final Color background;
  final Color border;
  const _MoneyBox(this.label, this.value, this.detail, {this.color = AppColors.text, this.background = AppColors.canvas, this.border = AppColors.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: AppText.mono(size: 9.5, color: color == AppColors.text ? AppColors.textMuted : color)),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AppText.sans(size: 17, weight: FontWeight.w800, color: color))),
        Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(size: 10.5, color: AppColors.textMuted)),
      ]),
    );
  }
}

class _ConceptCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final String detail;
  const _ConceptCard(this.label, this.icon, this.value, this.detail);

  @override
  Widget build(BuildContext context) {
    return SpCard(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.mono(size: 10.5, color: AppColors.textSecondary))),
        ]),
        const SizedBox(height: 8),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AppText.sans(size: 20, weight: FontWeight.w800))),
        Text(detail, style: AppText.small),
      ]),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final CashPayment payment;
  const _PaymentRow(this.payment);

  @override
  Widget build(BuildContext context) {
    final monthly = payment.concept == 'MONTHLY';
    final meta = vehicleMeta(payment.vehicleType);
    return SpCard(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(meta.icon, size: 18, color: AppColors.textSecondary),
            Text(meta.label.toUpperCase(), style: AppText.mono(size: 7.5, color: AppColors.textMuted)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (monthly) ...[Text('Mensual', style: AppText.mono(size: 12.5, color: AppColors.amber)), const SizedBox(width: 6)],
              if (payment.plate != null) PlateBadge(payment.plate!),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(payment.method == 'ONLINE' ? Icons.qr_code_2 : Icons.payments_outlined, size: 14, color: payment.method == 'ONLINE' ? AppColors.blue : AppColors.green),
              const SizedBox(width: 4),
              Text(paymentLabel(payment.method), style: AppText.sans(size: 12, weight: FontWeight.w700, color: payment.method == 'ONLINE' ? AppColors.blue : AppColors.green)),
              Text(' • ${hhmm(payment.paidAt)}', style: AppText.mono(size: 11.5, weight: FontWeight.w500, color: AppColors.textMuted)),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('+${money(payment.amount)}', style: AppText.sans(size: 17, weight: FontWeight.w800, color: AppColors.green)),
          Text(monthly ? 'MENSUALIDAD' : 'SALIDA', style: AppText.mono(size: 9.5, color: AppColors.textMuted)),
        ]),
      ]),
    );
  }
}
