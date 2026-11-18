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

/// Registro de entrada: mismas reglas que la web (espacio, llaves para carros, hasta 2 cascos por moto).
class EntryScreen extends ConsumerStatefulWidget {
  const EntryScreen({super.key});

  @override
  ConsumerState<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends ConsumerState<EntryScreen> {
  final _plate = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  String _vehicleType = 'CAR';
  bool _manageResources = true;
  ResourceBoard _board = const ResourceBoard();
  List<MonthlySubscription> _monthly = const [];
  List<PricingRule> _rules = const [];
  String? _space;
  String? _keySlot;
  final List<String> _helmets = [];
  bool _sendWhatsapp = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _plate.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _plate.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = ref.read(parkingApiProvider);
    try {
      final results = await Future.wait<Object?>([
        api.currentBranch(),
        api.resourceBoard(),
        api.monthlySubscriptions().catchError((_) => <MonthlySubscription>[]),
        api.pricingRules().catchError((_) => <PricingRule>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _manageResources = (results[0] as Branch?)?.manageResources ?? true;
        _board = results[1] as ResourceBoard;
        _monthly = results[2] as List<MonthlySubscription>;
        _rules = results[3] as List<PricingRule>;
        _error = null;
        _loading = false;
        _suggestSpace();
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  VehicleMeta get _meta => vehicleMeta(_vehicleType);
  List<Resource> get _spaces => !_manageResources ? const [] : (_meta.compact ? _board.motorcycleSpaces : _board.carSpaces);
  bool get _showsKeys => _manageResources && !_meta.compact;
  bool get _showsHelmets => _manageResources && _meta.compact;

  MonthlySubscription? get _monthlyMatch {
    final plate = cleanPlate(_plate.text);
    if (plate.length < 5) return null;
    return _monthly.where((item) => item.active && cleanPlate(item.plate) == plate).firstOrNull;
  }

  String get _rateLabel {
    final rule = _rules.where((item) => item.vehicleType == _vehicleType).firstOrNull;
    if (rule == null) return 'TARIFA: —';
    if (rule.pricingModel == 'FLAT') return 'TARIFA: ${money(rule.flatAmount)}';
    return 'TARIFA: ${money(rule.hourlyAmount)}/H';
  }

  void _suggestSpace() {
    _space = _spaces.where((item) => !item.taken).firstOrNull?.code;
  }

  void _selectType(String type) {
    setState(() {
      _vehicleType = type;
      _keySlot = null;
      _helmets.clear();
      _suggestSpace();
    });
  }

  void _toggleHelmet(String code) {
    setState(() {
      if (_helmets.contains(code)) {
        _helmets.remove(code);
      } else if (_helmets.length < _meta.maxHelmets) {
        _helmets.add(code);
      } else if (_meta.maxHelmets == 1) {
        _helmets
          ..clear()
          ..add(code);
      }
    });
  }

  Future<void> _pickSpace() async {
    final free = _spaces.where((item) => !item.taken).toList();
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionTitle('Espacios libres de ${_meta.compact ? 'motos' : 'carros'}'),
            if (free.isEmpty) Text('No hay espacios libres.', style: AppText.small),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final slot in free)
                _Chip(label: slot.code, selected: slot.code == _space, onTap: () => Navigator.pop(context, slot.code)),
            ]),
          ]),
        ),
      ),
    );
    if (chosen != null) setState(() => _space = chosen);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final plate = cleanPlate(_plate.text);
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    String? invalid;
    if (plate.length < 5) invalid = 'Ingrese una placa válida';
    if (invalid == null && phone.length < 7) invalid = 'Ingrese el celular del conductor';
    if (invalid == null && _manageResources && _space == null) {
      invalid = _spaces.isEmpty ? 'El parqueadero no tiene espacios de ${_meta.compact ? 'motos' : 'carros'} configurados' : 'No hay espacios libres: seleccione uno o espere una salida';
    }
    if (invalid != null) {
      showMessage(context, invalid, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await ref.read(parkingApiProvider).checkIn(
            plate: plate,
            vehicleType: _vehicleType,
            driverPhone: phone,
            driverName: _name.text,
            spaceCode: _manageResources ? _space : '',
            keySlotCode: _showsKeys ? _keySlot : '',
            helmetLockerCodes: _showsHelmets ? List.of(_helmets) : const [],
            monthlySubscription: _monthlyMatch != null,
            sendWhatsapp: _sendWhatsapp,
          );
      if (!mounted) return;
      await _showReceipt(result);
      _plate.clear();
      _name.clear();
      _phone.clear();
      _keySlot = null;
      _helmets.clear();
      await _load();
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showReceipt(CheckInResult result) {
    final ticket = result.ticket;
    final whatsapp = result.whatsapp;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Row(children: [
          const Icon(Icons.check_circle, color: AppColors.green),
          const SizedBox(width: 8),
          Expanded(child: Text('Entrada registrada', style: AppText.headline)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          PlateBadge(ticket.plate, large: true),
          const SizedBox(height: 14),
          if (ticket.code != null) AmountRow('Ticket', ticket.code!),
          AmountRow('Vehículo', vehicleMeta(ticket.vehicleType).label),
          AmountRow('Entrada', hhmm(ticket.checkedInAt)),
          if (ticket.spaceCode != null) AmountRow('Espacio', ticket.spaceCode!),
          if (ticket.keySlotCode != null) AmountRow('Llave', ticket.keySlotCode!),
          if (ticket.helmetLockerCodes.isNotEmpty) AmountRow('Cascos', ticket.helmetLockerCodes.join(', ')),
          if (ticket.monthlySubscription) const AmountRow('Modalidad', 'Mensualidad', valueColor: AppColors.blue),
          const SizedBox(height: 12),
          if (whatsapp != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: whatsapp.sent ? AppColors.greenLight : AppColors.amberLight,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: whatsapp.sent ? AppColors.greenBorder : AppColors.amberBorder),
              ),
              child: Text(
                whatsapp.sent ? 'Ticket enviado por WhatsApp' : 'No se envió por WhatsApp: ${whatsapp.error ?? 'error desconocido'}',
                style: AppText.sans(size: 12, weight: FontWeight.w600, color: whatsapp.sent ? AppColors.greenDark : AppColors.amber),
              ),
            ),
        ]),
        actions: [
          if (whatsapp != null && !whatsapp.sent)
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                try {
                  final status = await ref.read(parkingApiProvider).resendWhatsapp(ticket.uuid);
                  messenger.showSnackBar(SnackBar(content: Text(status.sent ? 'Ticket enviado por WhatsApp' : 'No se pudo enviar: ${status.error ?? ''}')));
                } on ApiException catch (error) {
                  messenger.showSnackBar(SnackBar(content: Text(error.message)));
                }
              },
              child: const Text('Reintentar WhatsApp'),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(context),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) return ListView(padding: const EdgeInsets.all(16), children: [ErrorPanel(_error!, onRetry: _load)]);
    final monthly = _monthlyMatch;
    final freeKeys = _board.keySlots.where((item) => !item.taken).length;
    final freeHelmets = _board.helmetLockers.where((item) => !item.taken).length;

    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            children: [
              Row(children: [
                const Icon(Icons.circle, size: 8, color: AppColors.green),
                const SizedBox(width: 6),
                Text(todayLabel(DateTime.now()), style: AppText.mono(size: 11, weight: FontWeight.w600, color: AppColors.textMuted)),
              ]),
              const SizedBox(height: 12),
              SectionTitle('Tipo de vehículo', icon: Icons.warning_amber_rounded, trailing: StatusChip.muted(_rateLabel)),
              Row(children: [
                for (final type in vehicleTypes)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _TypeTile(meta: type, selected: type.type == _vehicleType, onTap: () => _selectType(type.type)),
                    ),
                  ),
              ]),
              const SizedBox(height: 14),
              SpCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SectionTitle('Placa del vehículo', icon: Icons.pin_outlined, trailing: Text('OBLIGATORIO', style: AppText.mono(size: 10.5, color: AppColors.primary))),
                  _PlateInput(controller: _plate),
                  if (monthly != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.greenBorder)),
                      child: Row(children: [
                        const Icon(Icons.verified_outlined, color: AppColors.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Mensualidad vigente', style: AppText.sans(size: 14, weight: FontWeight.w800, color: AppColors.greenDark)),
                            Text('${monthly.customerName} · Vence: ${shortDate(monthly.expiresAt)}', style: AppText.sans(size: 12, color: AppColors.green)),
                          ]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.greenDark, borderRadius: BorderRadius.circular(AppRadius.sm)),
                          child: Text('TARIFA\n\$0', style: AppText.mono(size: 10.5, color: Colors.white)),
                        ),
                      ]),
                    ),
                  ],
                ]),
              ),
              if (_manageResources) ...[
                const SizedBox(height: 14),
                SpCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SectionTitle('Espacio asignado', icon: Icons.local_parking,
                        trailing: TextButton.icon(onPressed: _pickSpace, icon: const Icon(Icons.tune, size: 16), label: const Text('Cambiar'))),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        Container(
                          width: 58,
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _space == null ? AppColors.primaryLight : AppColors.greenLight,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: _space == null ? AppColors.primaryBorder : AppColors.green, width: 1.5),
                          ),
                          child: Text(_space ?? '—', style: AppText.mono(size: 15, weight: FontWeight.w800, color: _space == null ? AppColors.primary : AppColors.green)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_meta.compact ? 'Zona Motos' : 'Zona Carros', style: AppText.headline),
                            Text(
                              _space == null ? 'Sin espacios libres' : '${_spaces.where((item) => !item.taken).length} libres · primer espacio disponible',
                              style: AppText.sans(size: 12, color: AppColors.textMuted),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ],
              if (_showsKeys || _showsHelmets) ...[
                const SizedBox(height: 14),
                SpCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SectionTitle('Casilleros y custodia', icon: Icons.lock_outline, trailing: Text('OPCIONAL', style: AppText.meta)),
                    if (_showsKeys) ...[
                      Row(children: [
                        const Icon(Icons.key_outlined, size: 16, color: AppColors.amber),
                        const SizedBox(width: 6),
                        Expanded(child: Text('Tablero de llaves', style: AppText.sans(weight: FontWeight.w700))),
                        Text('$freeKeys libres', style: AppText.mono(size: 11, color: AppColors.green)),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _Chip(label: 'Ninguno', selected: _keySlot == null, onTap: () => setState(() => _keySlot = null)),
                        for (final slot in _board.keySlots.where((item) => !item.taken))
                          _Chip(label: slot.code, selected: _keySlot == slot.code, onTap: () => setState(() => _keySlot = slot.code)),
                      ]),
                    ],
                    if (_showsHelmets) ...[
                      Row(children: [
                        const Icon(Icons.sports_motorsports_outlined, size: 16, color: AppColors.amber),
                        const SizedBox(width: 6),
                        Expanded(child: Text(_meta.maxHelmets > 1 ? 'Casilleros de casco (máx. 2)' : 'Casillero de casco', style: AppText.sans(weight: FontWeight.w700))),
                        Text('$freeHelmets libres', style: AppText.mono(size: 11, color: AppColors.green)),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _Chip(label: 'Ninguno', selected: _helmets.isEmpty, onTap: () => setState(_helmets.clear)),
                        for (final slot in _board.helmetLockers.where((item) => !item.taken))
                          _Chip(label: slot.code, selected: _helmets.contains(slot.code), onTap: () => _toggleHelmet(slot.code)),
                      ]),
                    ],
                  ]),
                ),
              ],
              const SizedBox(height: 14),
              SpCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SectionTitle('Datos del conductor', icon: Icons.person_outline),
                  const FieldLabel('Nombre completo (opcional)'),
                  TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(suffixIcon: Icon(Icons.badge_outlined), hintText: 'Nombre del conductor')),
                  const SizedBox(height: 12),
                  const FieldLabel('Celular / WhatsApp *'),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    style: AppText.mono(size: 15, weight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: '310 456 7890',
                      prefixIcon: Container(
                        width: 52,
                        alignment: Alignment.center,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border))),
                        child: Text('+57', style: AppText.mono(size: 14, color: AppColors.textSecondary)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => setState(() => _sendWhatsapp = !_sendWhatsapp),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(color: AppColors.greenLight, shape: BoxShape.circle),
                          child: const Icon(Icons.chat_outlined, color: AppColors.green),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Enviar ticket por WhatsApp', style: AppText.sans(size: 14, weight: FontWeight.w800)),
                            Text('Plantilla: ticket_sp_parqueaderos', style: AppText.mono(size: 11, weight: FontWeight.w500, color: AppColors.green)),
                          ]),
                        ),
                        Checkbox(
                          value: _sendWhatsapp,
                          onChanged: (value) => setState(() => _sendWhatsapp = value ?? false),
                          fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.green : Colors.white),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [BoxShadow(color: Color(0x140F172A), blurRadius: 12, offset: Offset(0, -2))],
        ),
        child: PrimaryButton(label: 'REGISTRAR ENTRADA', icon: Icons.check_circle_outline, large: true, loading: _saving, onPressed: _submit),
      ),
    ]);
  }
}

class _TypeTile extends StatelessWidget {
  final VehicleMeta meta;
  final bool selected;
  final VoidCallback onTap;
  const _TypeTile({required this.meta, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      elevation: selected ? 3 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          height: 72,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: selected ? AppColors.primary : AppColors.border)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(meta.icon, size: 26, color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(height: 4),
            Text(meta.label, style: AppText.sans(size: 12, weight: FontWeight.w700, color: selected ? Colors.white : AppColors.textSecondary)),
          ]),
        ),
      ),
    );
  }
}

/// Campo de placa con el aspecto de la placa amarilla colombiana.
class _PlateInput extends StatelessWidget {
  final TextEditingController controller;
  const _PlateInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      decoration: BoxDecoration(color: AppColors.plateYellow, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.ink, width: 3)),
      child: Column(children: [
        Row(children: [
          Text('COLOMBIA', style: AppText.mono(size: 10, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: 1)),
          const Spacer(),
          if (controller.text.isNotEmpty)
            GestureDetector(onTap: controller.clear, child: const Icon(Icons.backspace_outlined, size: 18, color: AppColors.ink)),
        ]),
        TextField(
          controller: controller,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9 ]')),
            LengthLimitingTextInputFormatter(8),
            TextInputFormatter.withFunction((oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase())),
          ],
          style: AppText.mono(size: 34, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: 3),
          cursorColor: AppColors.ink,
          decoration: InputDecoration(
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            hintText: 'ABC 123',
            hintStyle: AppText.mono(size: 34, weight: FontWeight.w800, color: AppColors.ink.withValues(alpha: 0.25), letterSpacing: 3),
          ),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.amberLight : AppColors.canvas,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selected ? AppColors.amber : AppColors.border, width: selected ? 2 : 1),
        ),
        child: Text(selected && label != 'Ninguno' ? '$label ✓' : label,
            style: AppText.mono(size: 13, weight: FontWeight.w700, color: selected ? AppColors.amber : AppColors.textSecondary)),
      ),
    );
  }
}
