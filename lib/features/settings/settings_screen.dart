import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/parking_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';

/// Configuracion del parqueadero: tarifas por tipo de vehiculo (igual que la web).
/// Solo propietario y administrador; el servidor tambien lo exige.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  List<PricingRule> _rules = const [];
  Branch? _branch;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(parkingApiProvider);
    try {
      final results = await Future.wait<Object?>([api.pricingRules(), api.currentBranch().catchError((_) => null)]);
      final rules = results[0] as List<PricingRule>;
      // Mismo orden que el selector de la entrada: carro, moto, carga, bicicleta.
      final order = vehicleTypes.map((item) => item.type).toList();
      rules.sort((a, b) => order.indexOf(a.vehicleType).compareTo(order.indexOf(b.vehicleType)));
      if (mounted) {
        setState(() {
          _rules = rules;
          _branch = results[1] as Branch?;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(PricingRule rule) async {
    final saved = await Navigator.of(context).push<PricingRule>(MaterialPageRoute(builder: (_) => TariffEditorScreen(rule: rule)));
    if (saved == null || !mounted) return;
    setState(() => _rules = [for (final item in _rules) item.vehicleType == saved.vehicleType ? saved : item]);
    showMessage(context, 'Tarifa de ${saved.displayName} actualizada');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (auth.tenant?.canManage != true) return const RestrictedPanel('La configuración de tarifas');
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          SpCard(
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: const Icon(Icons.tune, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Configuración', style: AppText.display),
                  Text(_branch?.name ?? auth.tenant?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(color: AppColors.textMuted)),
                ]),
              ),
              StatusChip.blue(auth.tenant?.roleLabel ?? ''),
            ]),
          ),
          const SizedBox(height: 16),
          SectionTitle('Tarifas por tipo de vehículo', trailing: Text('${_rules.length} tipos', style: AppText.mono(size: 12, weight: FontWeight.w600, color: AppColors.textMuted))),
          if (_error != null) ErrorPanel(_error!, onRetry: _load),
          if (_error == null && _rules.isEmpty) SpCard(child: Text('No hay tarifas configuradas.', style: AppText.sans(color: AppColors.textMuted))),
          for (final rule in _rules) Padding(padding: const EdgeInsets.only(bottom: 10), child: _TariffCard(rule: rule, onEdit: () => _edit(rule))),
          const SizedBox(height: 6),
          SpCard(
            color: AppColors.blueLight,
            borderColor: AppColors.blueBorder,
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppColors.blue, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Los cambios aplican a las salidas que se cobren desde ahora. Los espacios, el horario y los usuarios se configuran desde la web.',
                    style: AppText.sans(size: 12, color: AppColors.textSecondary)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _TariffCard extends StatelessWidget {
  final PricingRule rule;
  final VoidCallback onEdit;
  const _TariffCard({required this.rule, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final meta = vehicleMeta(rule.vehicleType);
    return SpCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: AppColors.blueLight, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.blueBorder)),
            child: Icon(meta.icon, color: AppColors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rule.displayName, style: AppText.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(rule.flat ? 'Tarifa plana' : 'Primera hora + adicional', style: AppText.mono(size: 11, weight: FontWeight.w500, color: AppColors.textMuted)),
            ]),
          ),
          rule.active ? const StatusChip('Activa') : const StatusChip.muted('Inactiva'),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
          child: rule.flat
              ? Row(children: [
                  Expanded(child: _Value('Valor fijo', money(rule.flatAmount), color: AppColors.green)),
                  Expanded(child: _Value('Ticket perdido', rule.lostTicketFee == null ? '—' : money(rule.lostTicketFee))),
                ])
              : Column(children: [
                  Row(children: [
                    Expanded(child: _Value('1ª hora', money(rule.hourlyAmount), color: AppColors.green)),
                    Expanded(child: _Value('Hora adicional', money(rule.additional))),
                    Expanded(child: _Value('Por minuto', moneyDecimal(rule.additional / 60))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _Value('Valor día', rule.dayAmount == null || rule.dayAmount == 0 ? '—' : money(rule.dayAmount))),
                    Expanded(child: _Value('Tope diario', rule.applyDailyCap && (rule.dayAmount ?? 0) > 0 ? 'Sí' : 'No')),
                    Expanded(child: _Value('Ticket perdido', rule.lostTicketFee == null ? '—' : money(rule.lostTicketFee))),
                  ]),
                ]),
        ),
        const SizedBox(height: 12),
        GhostButton(label: 'Editar tarifa', icon: Icons.edit_outlined, onPressed: onEdit),
      ]),
    );
  }
}

class _Value extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Value(this.label, this.value, {this.color = AppColors.text});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: AppText.mono(size: 9.5, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AppText.mono(size: 14, weight: FontWeight.w800, color: color))),
    ]);
  }
}

/// Editor de una tarifa, con ejemplos de cobro que se recalculan mientras se escribe.
class TariffEditorScreen extends ConsumerStatefulWidget {
  final PricingRule rule;
  const TariffEditorScreen({super.key, required this.rule});

  @override
  ConsumerState<TariffEditorScreen> createState() => _TariffEditorScreenState();
}

class _TariffEditorScreenState extends ConsumerState<TariffEditorScreen> {
  late final _name = TextEditingController(text: widget.rule.displayName);
  late final _hourly = TextEditingController(text: _text(widget.rule.hourlyAmount));
  late final _additional = TextEditingController(text: _text(widget.rule.additionalHourAmount ?? widget.rule.hourlyAmount));
  late final _day = TextEditingController(text: _text(widget.rule.dayAmount));
  late final _lost = TextEditingController(text: _text(widget.rule.lostTicketFee));
  late final _flatAmount = TextEditingController(text: _text(widget.rule.flatAmount));
  late bool _flat = widget.rule.flat;
  late bool _cap = widget.rule.applyDailyCap;
  bool _saving = false;

  static String _text(double? value) => value == null ? '' : value.round().toString();
  static double? _value(TextEditingController controller) => controller.text.trim().isEmpty ? null : double.tryParse(controller.text.trim());

  @override
  void initState() {
    super.initState();
    for (final controller in [_hourly, _additional, _day, _flatAmount]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _hourly, _additional, _day, _lost, _flatAmount]) {
      controller.dispose();
    }
    super.dispose();
  }

  PricingRule get _draft => PricingRule(
        vehicleType: widget.rule.vehicleType,
        displayName: _name.text.trim().isEmpty ? vehicleMeta(widget.rule.vehicleType).label : _name.text.trim(),
        pricingModel: _flat ? 'FLAT' : 'PROGRESSIVE',
        flatAmount: _value(_flatAmount),
        hourlyAmount: _value(_hourly),
        additionalHourAmount: _value(_additional),
        dayAmount: _value(_day),
        applyDailyCap: _cap,
        // Campos que la pantalla no edita (como en la web): se conservan.
        rateIncreaseAfterHours: widget.rule.rateIncreaseAfterHours,
        rateIncreaseAmount: widget.rule.rateIncreaseAmount,
        lostTicketFee: _value(_lost),
        active: widget.rule.active,
      );

  String? _validate(PricingRule rule) {
    if (rule.flat) return (rule.flatAmount ?? 0) > 0 ? null : 'Ingrese el valor de la tarifa plana';
    if ((rule.hourlyAmount ?? 0) <= 0) return 'Ingrese el valor de la primera hora';
    if (rule.additionalHourAmount == null || rule.additionalHourAmount! < 0) return 'Ingrese el valor de la hora adicional';
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final rule = _draft;
    final invalid = _validate(rule);
    if (invalid != null) {
      showMessage(context, invalid, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref.read(parkingApiProvider).savePricingRule(rule);
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = vehicleMeta(widget.rule.vehicleType);
    final draft = _draft;
    return Scaffold(
      appBar: AppBar(
        title: Text('Tarifa · ${meta.label}'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          SpCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('Datos de la tarifa', icon: meta.icon),
              const FieldLabel('Nombre visible'),
              TextField(controller: _name, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(hintText: meta.label)),
              const SizedBox(height: 14),
              const FieldLabel('Modelo de cobro'),
              Row(children: [
                Expanded(child: _ModelButton(label: 'Por horas', icon: Icons.schedule, selected: !_flat, onTap: () => setState(() => _flat = false))),
                const SizedBox(width: 8),
                Expanded(child: _ModelButton(label: 'Tarifa plana', icon: Icons.sell_outlined, selected: _flat, onTap: () => setState(() => _flat = true))),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          SpCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Valores', icon: Icons.payments_outlined),
              if (_flat) ...[
                const FieldLabel('Valor tarifa plana *'),
                _MoneyField(controller: _flatAmount),
                const SizedBox(height: 8),
                Text('Se cobra este valor sin importar el tiempo que el vehículo esté adentro.', style: AppText.small),
              ] else ...[
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const FieldLabel('Primera hora *'), _MoneyField(controller: _hourly)])),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const FieldLabel('Hora adicional *'), _MoneyField(controller: _additional)])),
                ]),
                const SizedBox(height: 8),
                Text(
                  'La primera hora (o cualquier parte de ella) se cobra completa. Después, cada minuto se cobra proporcional a la hora adicional: '
                  '${moneyDecimal(draft.additional / 60)} por minuto.',
                  style: AppText.sans(size: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const FieldLabel('Valor día (24h)'), _MoneyField(controller: _day)])),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const FieldLabel('Ticket perdido'), _MoneyField(controller: _lost)])),
                ]),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
                  child: SwitchListTile(
                    value: _cap,
                    onChanged: (value) => setState(() => _cap = value),
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.green,
                    title: Text('Tope diario', style: AppText.sans(size: 14, weight: FontWeight.w700)),
                    subtitle: Text('No cobrar más del valor día en cada bloque de 24 horas', style: AppText.small),
                  ),
                ),
              ],
              if (_flat) ...[
                const SizedBox(height: 14),
                const FieldLabel('Ticket perdido'),
                _MoneyField(controller: _lost),
              ],
            ]),
          ),
          if (!_flat) ...[
            const SizedBox(height: 14),
            SpCard(
              color: AppColors.greenLight,
              borderColor: AppColors.greenBorder,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('Ejemplos con esta tarifa', barColor: AppColors.green),
                for (final example in const [(45, '45 min'), (80, '1 h 20 min'), (150, '2 h 30 min'), (300, '5 h')])
                  AmountRow(example.$2, money(draft.estimate(example.$1)), valueColor: AppColors.greenDark),
                if ((draft.dayAmount ?? 0) > 0) AmountRow('1 día + 2 h', money(draft.estimate(1560)), valueColor: AppColors.greenDark),
              ]),
            ),
          ],
          const SizedBox(height: 18),
          PrimaryButton(label: 'GUARDAR TARIFA', icon: Icons.check_circle_outline, large: true, loading: _saving, onPressed: _save),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ],
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  final TextEditingController controller;
  const _MoneyField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
      style: AppText.mono(size: 16),
      decoration: const InputDecoration(prefixText: '\$ ', hintText: '0'),
    );
  }
}

class _ModelButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ModelButton({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.canvas,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 48,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: selected ? AppColors.primary : AppColors.border)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 19, color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: AppText.sans(size: 13.5, weight: FontWeight.w800, color: selected ? Colors.white : AppColors.textSecondary))),
          ]),
        ),
      ),
    );
  }
}

