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
      // El servidor ya los entrega en orden: los 4 basicos y despues los agregados.
      final rules = results[0] as List<PricingRule>;
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
    _syncCatalog();
    showMessage(context, 'Tarifa de ${saved.displayName} actualizada');
  }

  /// Nuevo tipo de vehiculo: el mismo editor de tarifa, vacio y con la categoria.
  Future<void> _create() async {
    const draft = PricingRule(vehicleType: '', displayName: '', pricingModel: 'PROGRESSIVE', category: 'CAR', custom: true);
    final created = await Navigator.of(context).push<PricingRule>(MaterialPageRoute(builder: (_) => const TariffEditorScreen(rule: draft)));
    if (created == null || !mounted) return;
    setState(() => _rules = [..._rules, created]);
    _syncCatalog();
    showMessage(context, 'Tipo "${created.displayName}" agregado. Ya aparece al registrar entradas');
  }

  /// Elimina (desactiva) un tipo. El servidor lo rechaza si hay vehiculos adentro o mensualidades vigentes.
  Future<void> _delete(PricingRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('¿Eliminar "${rule.displayName}"?', style: AppText.headline),
        content: Text('Dejará de aparecer al registrar entradas y mensualidades. Los tickets y reportes anteriores conservan su nombre.',
            style: AppText.sans(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.primary), onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(parkingApiProvider).deleteVehicleType(rule.vehicleType);
      if (!mounted) return;
      setState(() => _rules = _rules.where((item) => item.vehicleType != rule.vehicleType).toList());
      _syncCatalog();
      showMessage(context, 'Tipo "${rule.displayName}" eliminado');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    }
  }

  /// Los tipos que muestra la app (entrada, tickets...) siguen el catalogo de esta pantalla.
  void _syncCatalog() {
    registerVehicleTypes(_rules.map((rule) => (rule.vehicleType, rule.displayName, rule.category)));
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
          SectionTitle('Tarifas y tipos de vehículo', trailing: Text('${_rules.length} tipos', style: AppText.mono(size: 12, weight: FontWeight.w600, color: AppColors.textMuted))),
          if (_error != null) ErrorPanel(_error!, onRetry: _load),
          if (_error == null && _rules.isEmpty) SpCard(child: Text('No hay tarifas configuradas.', style: AppText.sans(color: AppColors.textMuted))),
          for (final rule in _rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TariffCard(rule: rule, onEdit: () => _edit(rule), onDelete: _rules.length > 1 ? () => _delete(rule) : null),
            ),
          GhostButton(label: 'Agregar tipo de vehículo', icon: Icons.add, color: AppColors.primary, onPressed: _create),
          const SizedBox(height: 12),
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
  /// null = no se puede eliminar (es el ultimo tipo que queda).
  final VoidCallback? onDelete;
  const _TariffCard({required this.rule, required this.onEdit, this.onDelete});

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
              Text(meta.compact ? 'Espacios de moto · cascos' : 'Espacios de carro · llaves',
                  style: AppText.mono(size: 11, weight: FontWeight.w500, color: AppColors.textMuted)),
            ]),
          ),
          rule.custom ? const StatusChip.blue('Agregado') : const StatusChip('Básico'),
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
        Row(children: [
          Expanded(child: GhostButton(label: rule.flat ? 'Editar (tarifa plana)' : 'Editar tarifa', icon: Icons.edit_outlined, onPressed: onEdit)),
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 52,
              height: 46,
              child: OutlinedButton(
                onPressed: onDelete,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primaryBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                child: const Icon(Icons.delete_outline, semanticLabel: 'Eliminar tipo'),
              ),
            ),
          ],
        ]),
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
  /// CAR (como carro) o MOTORCYCLE (como moto): se elige al crear y se puede cambiar en los tipos agregados.
  late String _category = widget.rule.category;
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
        displayName: _name.text.trim().isEmpty && !widget.rule.isNew ? vehicleMeta(widget.rule.vehicleType).label : _name.text.trim(),
        category: _category,
        custom: widget.rule.custom,
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
    if (rule.isNew && rule.displayName.isEmpty) return 'Ingrese el nombre del tipo de vehículo';
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
      final api = ref.read(parkingApiProvider);
      final saved = rule.isNew ? await api.createVehicleType(rule) : await api.savePricingRule(rule);
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final creating = widget.rule.isNew;
    final meta = vehicleMeta(creating ? (_category == 'MOTORCYCLE' ? 'MOTORCYCLE' : 'CAR') : widget.rule.vehicleType);
    final draft = _draft;
    return Scaffold(
      appBar: AppBar(
        title: Text(creating ? 'Nuevo tipo de vehículo' : 'Tarifa · ${meta.label}'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          SpCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle(creating ? 'Datos del tipo' : 'Datos de la tarifa', icon: meta.icon),
              // Categoria: al crear y en tipos agregados; los 4 basicos la tienen fija.
              if (creating || widget.rule.custom) ...[
                const FieldLabel('¿Cómo se parquea? *'),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: _CategoryOption(
                      icon: Icons.airport_shuttle_outlined,
                      title: 'Como carro',
                      detail: 'Espacios de carro y tablero de llaves',
                      selected: _category != 'MOTORCYCLE',
                      onTap: () => setState(() => _category = 'CAR'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CategoryOption(
                      icon: Icons.electric_scooter,
                      title: 'Como moto',
                      detail: 'Espacios de moto y hasta 2 cascos',
                      selected: _category == 'MOTORCYCLE',
                      onTap: () => setState(() => _category = 'MOTORCYCLE'),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
              ],
              FieldLabel(creating ? 'Nombre del tipo *' : 'Nombre visible'),
              TextField(
                controller: _name,
                maxLength: 40,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: creating ? 'Ej: Camioneta, Patineta eléctrica' : meta.label, counterText: ''),
              ),
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
          PrimaryButton(label: widget.rule.isNew ? 'AGREGAR TIPO' : 'GUARDAR TARIFA', icon: Icons.check_circle_outline, large: true, loading: _saving, onPressed: _save),
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

/// Opcion de categoria del tipo de vehiculo (como carro / como moto).
class _CategoryOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryOption({required this.icon, required this.title, required this.detail, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryLight : Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(title, style: AppText.sans(size: 14, weight: FontWeight.w800, color: selected ? AppColors.primary : AppColors.text)),
            const SizedBox(height: 2),
            Text(detail, style: AppText.sans(size: 11.5, color: AppColors.textMuted)),
          ]),
        ),
      ),
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

