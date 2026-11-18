import 'dart:async';
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

/// Salida y cobro. El valor lo calcula pricing-service; el servidor lo recalcula al confirmar.
class ExitScreen extends ConsumerStatefulWidget {
  final String? initialPlate;
  const ExitScreen({super.key, this.initialPlate});

  @override
  ConsumerState<ExitScreen> createState() => _ExitScreenState();
}

class _ExitScreenState extends ConsumerState<ExitScreen> {
  final _search = TextEditingController();
  final _received = TextEditingController();
  final _reference = TextEditingController();
  final _discount = TextEditingController();
  final _discountReason = TextEditingController();
  bool _showDiscount = false;

  List<Ticket> _active = const [];
  Ticket? _ticket;
  PricingCalculation? _price;
  String _method = 'CASH';
  bool _loading = true;
  bool _searching = false;
  bool _paying = false;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _received.addListener(() => setState(() {}));
    _discount.addListener(() => setState(() {}));
    _discountReason.addListener(() => setState(() {}));
    _loadActive().then((_) {
      final plate = widget.initialPlate;
      if (plate != null && plate.isNotEmpty) {
        _search.text = displayPlate(plate);
        _find();
      }
    });
    // El tiempo y el valor avanzan mientras el vehiculo sigue adentro.
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_ticket != null && !_paying) _reprice();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    _received.dispose();
    _reference.dispose();
    _discount.dispose();
    _discountReason.dispose();
    super.dispose();
  }

  Future<void> _loadActive() async {
    try {
      final active = await ref.read(parkingApiProvider).activeTickets();
      if (mounted) setState(() => _active = active);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _find([Ticket? chosen]) async {
    FocusScope.of(context).unfocus();
    final plate = cleanPlate(chosen?.plate ?? _search.text);
    if (plate.length < 3) {
      showMessage(context, 'Escribe la placa del vehículo', error: true);
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final ticket = chosen ?? _active.where((item) => cleanPlate(item.plate) == plate).firstOrNull ?? await ref.read(parkingApiProvider).ticketByPlate(plate);
      _search.text = displayPlate(ticket.plate);
      _ticket = ticket;
      _price = null;
      _received.clear();
      _reference.clear();
      _resetDiscount();
      _method = 'CASH';
      await _reprice();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _ticket = null;
          _error = error.message;
        });
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _reprice() async {
    final ticket = _ticket;
    if (ticket == null || ticket.monthlySubscription) {
      if (mounted) setState(() {});
      return;
    }
    try {
      final price = await ref.read(parkingApiProvider).calculate(ticket);
      if (mounted && _ticket?.uuid == ticket.uuid) setState(() => _price = price);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  double get _total => _ticket?.monthlySubscription == true ? 0 : (_price?.total ?? 0);
  double get _receivedAmount => double.tryParse(_received.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
  /// Descuento de monto exacto en pesos (no porcentaje).
  double get _discountAmount => _ticket?.monthlySubscription == true ? 0 : (double.tryParse(_discount.text.replaceAll(RegExp(r'\D'), '')) ?? 0);
  /// Lo que se cobra: tarifa menos descuento.
  double get _payable => (_total - _discountAmount) < 0 ? 0 : _total - _discountAmount;

  void _resetDiscount() {
    _discount.clear();
    _discountReason.clear();
    _showDiscount = false;
  }

  Future<void> _confirm() async {
    final ticket = _ticket;
    if (ticket == null) return;
    if (_discountAmount > _total) {
      showMessage(context, 'El descuento no puede ser mayor que el total (${money(_total)})', error: true);
      return;
    }
    if (_method == 'CASH' && _received.text.isNotEmpty && _receivedAmount < _payable) {
      showMessage(context, 'El efectivo recibido es menor al total', error: true);
      return;
    }
    setState(() => _paying = true);
    try {
      final closed = await ref.read(parkingApiProvider).checkOut(ticket.uuid,
          paymentMethod: _method, onlineReference: _reference.text, discountAmount: _discountAmount, discountReason: _discountReason.text);
      if (!mounted) return;
      final amount = closed.amountDue ?? 0;
      final charge = closed.monthlySubscription ? 'Mensualidad, sin cobro' : (amount > 0 ? 'Cobro: ${money(amount)} (${paymentLabel(closed.paymentMethod).toLowerCase()})' : 'Sin cobro');
      final discountText = (closed.discountAmount ?? 0) > 0 ? ' · descuento ${money(closed.discountAmount)}' : '';
      showMessage(context, 'Salida de ${displayPlate(closed.plate)} registrada. $charge$discountText');
      setState(() {
        _ticket = null;
        _price = null;
        _search.clear();
        _received.clear();
        _reference.clear();
        _resetDiscount();
      });
      await _loadActive();
    } on ApiException catch (error) {
      // Si el cobro no entra a caja el servidor revierte la salida: el vehiculo sigue adentro.
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    final ticket = _ticket;
    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadActive,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            children: [
              Row(children: [
                Expanded(child: Text('IDENTIFICAR VEHÍCULO ADENTRO', style: AppText.meta)),
                Text('${_active.length} adentro', style: AppText.mono(size: 12, color: AppColors.green)),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: _search,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _find(),
                style: AppText.mono(size: 20, weight: FontWeight.w800, letterSpacing: 1.5),
                decoration: InputDecoration(
                  fillColor: Colors.white,
                  hintText: 'Placa',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searching
                      ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                      : IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => _find()),
                ),
              ),
              if (_active.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final item in _active)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          onPressed: () => _find(item),
                          backgroundColor: item.uuid == ticket?.uuid ? AppColors.primaryLight : Colors.white,
                          side: BorderSide(color: item.uuid == ticket?.uuid ? AppColors.primaryBorder : AppColors.border),
                          avatar: Icon(vehicleMeta(item.vehicleType).icon, size: 16, color: AppColors.primary),
                          label: Text('${displayPlate(item.plate)}${item.spaceCode == null ? '' : ' (${item.spaceCode})'}', style: AppText.mono(size: 12)),
                        ),
                      ),
                  ]),
                ),
              ],
              if (_error != null) ...[const SizedBox(height: 12), ErrorPanel(_error!)],
              if (ticket == null && _error == null && !_searching) ...[
                const SizedBox(height: 40),
                const Icon(Icons.manage_search, size: 56, color: AppColors.textDisabled),
                const SizedBox(height: 8),
                Text('Busca la placa o toca un vehículo de la lista para cobrar su salida.', textAlign: TextAlign.center, style: AppText.sans(color: AppColors.textMuted)),
              ],
              if (ticket != null) ...[
                const SizedBox(height: 14),
                _TicketCard(ticket: ticket, price: _price, total: _total, discount: _discountAmount, discountReason: _discountReason.text.trim()),
                const SizedBox(height: 14),
                if (!ticket.monthlySubscription && _price != null) ...[_discountCard(), const SizedBox(height: 14)],
                if (!ticket.monthlySubscription && _payable > 0) _paymentCard(),
              ],
            ],
          ),
        ),
      ),
      if (ticket != null)
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [BoxShadow(color: Color(0x140F172A), blurRadius: 12, offset: Offset(0, -2))],
          ),
          child: PrimaryButton(
            label: ticket.monthlySubscription || _price != null && _payable == 0 ? 'CONFIRMAR SALIDA' : 'COBRAR ${money(_payable)} Y DAR SALIDA',
            icon: Icons.check_circle_outline,
            large: true,
            loading: _paying,
            onPressed: !ticket.monthlySubscription && _price == null ? null : _confirm,
          ),
        ),
    ]);
  }

  /// Descuento de monto exacto (ej. $2.000), no porcentual. Queda en la auditoria con el usuario que lo aplico.
  Widget _discountCard() {
    final tooHigh = _discountAmount > _total;
    if (!_showDiscount) {
      return GhostButton(label: 'Aplicar descuento', icon: Icons.sell_outlined, color: AppColors.green, onPressed: () => setState(() => _showDiscount = true));
    }
    return SpCard(
      color: AppColors.greenLight,
      borderColor: AppColors.greenBorder,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle('Descuento', icon: Icons.sell_outlined, trailing: TextButton(
          onPressed: () => setState(_resetDiscount),
          child: Text('Quitar', style: AppText.sans(size: 13, weight: FontWeight.w700, color: AppColors.primary)),
        )),
        const FieldLabel('Valor a descontar (pesos)'),
        TextField(
          controller: _discount,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
          style: AppText.mono(size: 18, color: AppColors.greenDark),
          decoration: InputDecoration(fillColor: Colors.white, prefixText: '− \$ ', hintText: '2000', errorText: tooHigh ? 'No puede ser mayor que el total (${money(_total)})' : null),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final value in const [1000, 2000, 5000]) _QuickAmount(label: money(value), onTap: () => _discount.text = '$value'),
        ]),
        const SizedBox(height: 12),
        const FieldLabel('Motivo (opcional)'),
        TextField(
          controller: _discountReason,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(fillColor: Colors.white, hintText: 'Cliente frecuente, convenio...', counterText: ''),
        ),
      ]),
    );
  }

  Widget _paymentCard() {
    final change = _receivedAmount - _payable;
    return SpCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle('Método de pago', icon: Icons.payments_outlined, trailing: Text('Selecciona uno', style: AppText.small)),
        Row(children: [
          Expanded(child: _MethodButton(label: 'Efectivo', icon: Icons.payments_outlined, selected: _method == 'CASH', onTap: () => setState(() => _method = 'CASH'))),
          const SizedBox(width: 8),
          Expanded(child: _MethodButton(label: 'En línea', icon: Icons.qr_code_2, selected: _method == 'ONLINE', onTap: () => setState(() => _method = 'ONLINE'))),
        ]),
        const SizedBox(height: 14),
        if (_method == 'CASH') ...[
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const FieldLabel('Recibido'),
                TextField(
                  controller: _received,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppText.mono(size: 16),
                  decoration: const InputDecoration(prefixText: '\$ ', hintText: '0'),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const FieldLabel('Cambio'),
                Container(
                  height: 48,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: change >= 0 ? AppColors.greenLight : AppColors.subtle,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: change >= 0 ? AppColors.greenBorder : AppColors.border),
                  ),
                  child: Text(_received.text.isEmpty ? '—' : (change >= 0 ? money(change) : 'Falta ${money(-change)}'),
                      style: AppText.mono(size: 16, color: change >= 0 ? AppColors.greenDark : AppColors.primary)),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('RÁPIDO:', style: AppText.meta),
            _QuickAmount(label: 'Exacto', onTap: () => _received.text = _payable.round().toString()),
            for (final value in const [10000, 20000, 50000]) _QuickAmount(label: money(value), onTap: () => _received.text = '$value'),
          ]),
        ] else ...[
          const FieldLabel('Referencia (opcional)'),
          TextField(controller: _reference, decoration: const InputDecoration(prefixIcon: Icon(Icons.tag), hintText: 'Nequi, Daviplata, datáfono...')),
        ],
      ]),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Ticket ticket;
  final PricingCalculation? price;
  final double total;
  final double discount;
  final String discountReason;
  const _TicketCard({required this.ticket, required this.price, required this.total, this.discount = 0, this.discountReason = ''});

  @override
  Widget build(BuildContext context) {
    final meta = vehicleMeta(ticket.vehicleType);
    final custody = [
      if (ticket.keySlotCode != null) ('Llave', ticket.keySlotCode!, Icons.key_outlined),
      ...ticket.helmetLockerCodes.map((code) => ('Casco', code, Icons.sports_motorsports_outlined)),
    ];
    final firstHour = price == null ? 0.0 : price!.total - price!.additionalAmount;
    return SpCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Text(ticket.code ?? 'SP-TICKET', style: AppText.mono(size: 11, color: Colors.white)),
              ),
              const SizedBox(height: 8),
              Text('${meta.label.toUpperCase()}${ticket.spaceCode == null ? '' : ' · ${ticket.spaceCode}'}', style: AppText.mono(size: 13, weight: FontWeight.w700, color: AppColors.textSecondary)),
              if (ticket.driverName != null) Text(ticket.driverName!, style: AppText.small),
            ]),
          ),
          PlateBadge(ticket.plate, large: true),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _TimeBox('Entrada', hhmm(ticket.checkedInAt))),
          const SizedBox(width: 6),
          Expanded(child: _TimeBox('Salida', hhmm(DateTime.now()), color: AppColors.primary)),
          const SizedBox(width: 6),
          Expanded(child: _TimeBox('Tiempo', duration(ticket.elapsed), highlight: true)),
        ]),
        if (custody.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.amberLight, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.amberBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.amber),
                const SizedBox(width: 6),
                Expanded(child: Text('ENTREGAR ANTES DE LA SALIDA:', style: AppText.mono(size: 11.5, weight: FontWeight.w800, color: AppColors.amber))),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final item in custody)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.amberBorder)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(item.$3, size: 15, color: AppColors.amber),
                      const SizedBox(width: 4),
                      Text('${item.$1}: ', style: AppText.sans(size: 12, weight: FontWeight.w700)),
                      Text(item.$2, style: AppText.mono(size: 12.5, color: AppColors.primary)),
                    ]),
                  ),
              ]),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        const Divider(),
        const SizedBox(height: 8),
        if (ticket.monthlySubscription)
          const AmountRow('Mensualidad vigente', 'Sin cobro', valueColor: AppColors.blue)
        else if (price == null)
          const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else ...[
          if (price!.days > 0) AmountRow('Días cobrados', '${price!.days}'),
          if (price!.firstHourCharged || price!.days > 0) AmountRow(price!.days > 0 ? 'Valor por días y primera hora' : '1ª hora ${meta.label}', money(firstHour)),
          if (price!.additionalMinutes > 0) AmountRow('Adicional (${price!.additionalMinutes} min)', money(price!.additionalAmount)),
          if (discount > 0) ...[
            AmountRow('Subtotal', money(total)),
            AmountRow(discountReason.isEmpty ? 'Descuento' : 'Descuento ($discountReason)', '−${money(discount > total ? total : discount)}', valueColor: AppColors.green),
          ],
        ],
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TOTAL A PAGAR', style: AppText.mono(size: 12.5, weight: FontWeight.w800)),
              Text('Calculado por el servidor', style: AppText.small),
            ]),
          ),
          Text(money(discount >= total ? 0 : total - discount), style: AppText.sans(size: 34, weight: FontWeight.w800, color: AppColors.primary, letterSpacing: -1)),
        ]),
      ]),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool highlight;
  const _TimeBox(this.label, this.value, {this.color = AppColors.text, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primaryLight : AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: highlight ? AppColors.primaryBorder : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: AppText.mono(size: 9.5, weight: FontWeight.w700, color: highlight ? AppColors.primaryDark : AppColors.textMuted)),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AppText.mono(size: 15, weight: FontWeight.w800, color: highlight ? AppColors.primary : color))),
      ]),
    );
  }
}

class _MethodButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _MethodButton({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.canvas,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 50,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: selected ? AppColors.primary : AppColors.border)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 20, color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: AppText.sans(size: 14, weight: FontWeight.w800, color: selected ? Colors.white : AppColors.textSecondary)),
          ]),
        ),
      ),
    );
  }
}

class _QuickAmount extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickAmount({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: AppColors.subtle, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: AppColors.borderStrong)),
        child: Text(label, style: AppText.mono(size: 12)),
      ),
    );
  }
}
