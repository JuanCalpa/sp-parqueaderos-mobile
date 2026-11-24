import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/parking_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';

enum _Tone { green, blue, amber, red }

/// Etiqueta, color e icono de cada accion auditada (mismas acciones que la web).
class _ActionMeta {
  final String label;
  final _Tone tone;
  final IconData icon;
  const _ActionMeta(this.label, this.tone, this.icon);
}

const _actions = <String, _ActionMeta>{
  'CHECK_IN': _ActionMeta('Entrada', _Tone.green, Icons.login),
  'CHECK_OUT': _ActionMeta('Salida', _Tone.blue, Icons.logout),
  'MONTHLY_CREATE': _ActionMeta('Mensualidad creada', _Tone.green, Icons.badge_outlined),
  'MONTHLY_UPDATE': _ActionMeta('Mensualidad editada', _Tone.amber, Icons.edit_outlined),
  'MONTHLY_RENEW': _ActionMeta('Mensualidad renovada', _Tone.green, Icons.autorenew),
  'MONTHLY_CANCEL': _ActionMeta('Mensualidad cancelada', _Tone.red, Icons.block),
  'MONTHLY_REMINDER': _ActionMeta('Recordatorio de mensualidad', _Tone.blue, Icons.chat_outlined),
  'CASH_OPEN': _ActionMeta('Apertura de caja', _Tone.blue, Icons.lock_open_outlined),
  'CASH_CLOSE': _ActionMeta('Cierre de caja', _Tone.blue, Icons.point_of_sale_outlined),
  'TARIFF_UPDATE': _ActionMeta('Tarifa modificada', _Tone.amber, Icons.sell_outlined),
  'VEHICLE_TYPE_CREATE': _ActionMeta('Tipo de vehículo agregado', _Tone.green, Icons.add_circle_outline),
  'VEHICLE_TYPE_DELETE': _ActionMeta('Tipo de vehículo eliminado', _Tone.red, Icons.delete_outline),
  'BRANCH_UPDATE': _ActionMeta('Configuración de sede', _Tone.amber, Icons.storefront_outlined),
  'MEMBER_ADD': _ActionMeta('Usuario agregado', _Tone.green, Icons.person_add_alt),
  'MEMBER_UPDATE': _ActionMeta('Usuario modificado', _Tone.amber, Icons.manage_accounts_outlined),
  'MEMBER_REMOVE': _ActionMeta('Usuario retirado', _Tone.red, Icons.person_remove_outlined),
  'MEMBER_RESET_PASSWORD': _ActionMeta('Clave restablecida', _Tone.red, Icons.key_outlined),
};

_ActionMeta _meta(String action) => _actions[action] ?? _ActionMeta(action, _Tone.blue, Icons.history);

(Color, Color, Color) _colors(_Tone tone) => switch (tone) {
      _Tone.green => (AppColors.green, AppColors.greenLight, AppColors.greenBorder),
      _Tone.blue => (AppColors.blue, AppColors.blueLight, AppColors.blueBorder),
      _Tone.amber => (AppColors.amber, AppColors.amberLight, AppColors.amberBorder),
      _Tone.red => (AppColors.primary, AppColors.primaryLight, AppColors.primaryBorder),
    };

/// Auditoria: quien hizo que y cuando. Solo propietario y administrador (el servidor tambien lo exige).
class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  final _query = TextEditingController();
  late DateTimeRange _range = _defaultRange();
  String? _action;
  String? _actor;
  AuditPage? _page;
  bool _loading = false;
  bool _showFilters = false;
  String? _error;

  static DateTimeRange _defaultRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today);
  }

  @override
  void initState() {
    super.initState();
    if (ref.read(authProvider).tenant?.canManage == true) _search();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref.read(parkingApiProvider).audit(from: _range.start, to: _range.end, action: _action, actor: _actor, query: _query.text);
      if (mounted) setState(() => _page = page);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _range,
      helpText: 'Rango de fechas',
      saveText: 'Aplicar',
    );
    if (picked != null) {
      setState(() => _range = picked);
      _search();
    }
  }

  void _clear() {
    _query.clear();
    setState(() {
      _range = _defaultRange();
      _action = null;
      _actor = null;
    });
    _search();
  }

  int get _activeFilters => [_action, _actor, _query.text.trim().isEmpty ? null : _query.text].where((item) => item != null).length;

  @override
  Widget build(BuildContext context) {
    if (ref.watch(authProvider).tenant?.canManage != true) return const RestrictedPanel('La auditoría');
    final entries = _page?.entries ?? const <AuditEntry>[];
    final days = <String, List<AuditEntry>>{};
    for (final entry in entries) {
      final local = (entry.createdAt ?? DateTime.now()).toLocal();
      days.putIfAbsent(todayLabel(local), () => []).add(entry);
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _search,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          SpCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: const Icon(Icons.manage_search, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Auditoría', style: AppText.display),
                    Text('Quién hizo qué y cuándo', style: AppText.sans(color: AppColors.textMuted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickRange,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(color: AppColors.subtle, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    const Icon(Icons.date_range_outlined, size: 20, color: AppColors.textMuted),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${shortDate(_range.start)}  →  ${shortDate(_range.end)}', style: AppText.mono(size: 13.5, weight: FontWeight.w700))),
                    const Icon(Icons.expand_more, color: AppColors.textMuted),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _query,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Placa, referencia o detalle',
                  suffixIcon: IconButton(
                    tooltip: 'Más filtros',
                    icon: Badge(isLabelVisible: _action != null || _actor != null, smallSize: 8, backgroundColor: AppColors.primary, child: const Icon(Icons.tune)),
                    onPressed: () => setState(() => _showFilters = !_showFilters),
                  ),
                ),
              ),
              if (_showFilters) ...[
                const SizedBox(height: 10),
                const FieldLabel('Acción'),
                DropdownButtonFormField<String?>(
                  initialValue: _action,
                  isExpanded: true,
                  decoration: const InputDecoration(),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Todas las acciones')),
                    for (final entry in _actions.entries) DropdownMenuItem<String?>(value: entry.key, child: Text(entry.value.label)),
                  ],
                  onChanged: (value) => setState(() => _action = value),
                ),
                const SizedBox(height: 10),
                const FieldLabel('Usuario'),
                DropdownButtonFormField<String?>(
                  initialValue: _actor,
                  isExpanded: true,
                  decoration: const InputDecoration(),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Todos los usuarios')),
                    for (final actor in _page?.actors ?? const <String>[]) DropdownMenuItem<String?>(value: actor, child: Text(actor)),
                  ],
                  onChanged: (value) => setState(() => _actor = value),
                ),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(flex: 3, child: PrimaryButton(label: 'BUSCAR', icon: Icons.search, loading: _loading, onPressed: _search)),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: GhostButton(label: _activeFilters > 0 ? 'Limpiar ($_activeFilters)' : 'Limpiar', icon: Icons.filter_alt_off_outlined, onPressed: _clear)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          if (_error != null) ErrorPanel(_error!, onRetry: _search),
          if (_page != null && _error == null) ...[
            SectionTitle('Actividad registrada', trailing: Text('${entries.length} registros', style: AppText.mono(size: 12, weight: FontWeight.w600, color: AppColors.textMuted))),
            if (_page!.truncated)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SpCard(
                  color: AppColors.amberLight,
                  borderColor: AppColors.amberBorder,
                  padding: const EdgeInsets.all(12),
                  child: Text('Se muestran los 500 registros más recientes. Acota las fechas o usa los filtros para ver el resto.',
                      style: AppText.sans(size: 12, weight: FontWeight.w600, color: AppColors.amber)),
                ),
              ),
            if (entries.isEmpty) SpCard(child: Text('No hay actividad registrada con esos filtros.', style: AppText.sans(color: AppColors.textMuted))),
            for (final day in days.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
                child: Row(children: [
                  Text(day.key, style: AppText.mono(size: 11.5, weight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.6)),
                  const SizedBox(width: 8),
                  const Expanded(child: Divider()),
                  const SizedBox(width: 8),
                  Text('${day.value.length}', style: AppText.mono(size: 11, color: AppColors.textMuted)),
                ]),
              ),
              for (final entry in day.value) Padding(padding: const EdgeInsets.only(bottom: 8), child: _EntryCard(entry)),
            ],
          ],
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final AuditEntry entry;
  const _EntryCard(this.entry);

  @override
  Widget build(BuildContext context) {
    final meta = _meta(entry.action);
    final (color, background, border) = _colors(meta.tone);
    return SpCard(
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: border)),
          child: Icon(meta.icon, size: 19, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(meta.label, style: AppText.sans(size: 14, weight: FontWeight.w800, color: color))),
              const SizedBox(width: 8),
              Text(hhmm(entry.createdAt), style: AppText.mono(size: 11.5, weight: FontWeight.w600, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(child: Text(entry.actor ?? 'Sistema', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.textSecondary))),
            ]),
            if (entry.entityRef != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.subtle, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: AppColors.border)),
                child: Text(entry.entityRef!, style: AppText.mono(size: 12)),
              ),
            ],
            if (entry.details != null) ...[
              const SizedBox(height: 6),
              Text(entry.details!, style: AppText.sans(size: 12.5, color: AppColors.textSecondary)),
            ],
            if (entry.source != null) ...[
              const SizedBox(height: 4),
              Text(entry.source!.toUpperCase(), style: AppText.mono(size: 9.5, color: AppColors.textDisabled)),
            ],
          ]),
        ),
      ]),
    );
  }
}
