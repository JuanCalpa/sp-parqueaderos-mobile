import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/parking_api.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';

/// Consulta de mensualidades. Crear, renovar y cancelar se agregan en la siguiente fase (hoy se hacen en la web).
class MonthlyScreen extends ConsumerStatefulWidget {
  const MonthlyScreen({super.key});

  @override
  ConsumerState<MonthlyScreen> createState() => _MonthlyScreenState();
}

class _MonthlyScreenState extends ConsumerState<MonthlyScreen> {
  final _search = TextEditingController();
  List<MonthlySubscription> _items = const [];
  String _filter = 'ACTIVE';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await ref.read(parkingApiProvider).monthlySubscriptions();
      items.sort((a, b) => (a.expiresAt ?? DateTime(9999)).compareTo(b.expiresAt ?? DateTime(9999)));
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    final query = cleanPlate(_search.text);
    final text = _search.text.trim().toLowerCase();
    final visible = _items.where((item) {
      if (_filter == 'EXPIRING' && !(item.active && item.daysLeft <= 5)) return false;
      if (_filter != 'EXPIRING' && _filter != 'ALL' && item.status != _filter) return false;
      if (text.isEmpty) return true;
      return cleanPlate(item.plate).contains(query) || item.customerName.toLowerCase().contains(text);
    }).toList();
    final counts = {
      'ACTIVE': _items.where((item) => item.active).length,
      'EXPIRING': _items.where((item) => item.active && item.daysLeft <= 5).length,
      'EXPIRED': _items.where((item) => item.status == 'EXPIRED').length,
      'ALL': _items.length,
    };

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          if (_error != null) ...[ErrorPanel(_error!, onRetry: _load), const SizedBox(height: 12)],
          TextField(
            controller: _search,
            decoration: const InputDecoration(fillColor: Colors.white, prefixIcon: Icon(Icons.search), hintText: 'Buscar por placa o cliente'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final entry in const [('ACTIVE', 'Vigentes'), ('EXPIRING', 'Por vencer'), ('EXPIRED', 'Vencidas'), ('ALL', 'Todas')])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${entry.$2} (${counts[entry.$1]})'),
                    selected: _filter == entry.$1,
                    onSelected: (_) => setState(() => _filter = entry.$1),
                    selectedColor: AppColors.primaryLight,
                    side: BorderSide(color: _filter == entry.$1 ? AppColors.primaryBorder : AppColors.border),
                    labelStyle: AppText.sans(size: 12.5, weight: FontWeight.w700, color: _filter == entry.$1 ? AppColors.primary : AppColors.textSecondary),
                    showCheckmark: false,
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty) SpCard(child: Text('No hay mensualidades para mostrar.', style: AppText.sans(color: AppColors.textMuted))),
          for (final item in visible) Padding(padding: const EdgeInsets.only(bottom: 10), child: _MonthlyCard(item)),
          const SizedBox(height: 8),
          Text('Para crear, renovar o cancelar mensualidades usa la web por ahora.', textAlign: TextAlign.center, style: AppText.small),
        ],
      ),
    );
  }
}

class _MonthlyCard extends StatelessWidget {
  final MonthlySubscription item;
  const _MonthlyCard(this.item);

  @override
  Widget build(BuildContext context) {
    final meta = vehicleMeta(item.vehicleType);
    final days = item.daysLeft;
    final Widget chip = switch (item.status) {
      'ACTIVE' when days <= 5 => StatusChip.amber(days == 0 ? 'Vence hoy' : 'Vence en $days d'),
      'ACTIVE' => const StatusChip('Vigente'),
      'EXPIRED' => const StatusChip.red('Vencida'),
      _ => const StatusChip.muted('Cancelada'),
    };
    return SpCard(
      borderColor: item.active ? AppColors.blueBorder : AppColors.border,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PlateBadge(item.plate, monthly: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(meta.icon, size: 16, color: AppColors.blue),
                const SizedBox(width: 4),
                Text(meta.label, style: AppText.sans(weight: FontWeight.w700)),
              ]),
              Text(item.customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(size: 12, color: AppColors.textMuted)),
            ]),
          ),
          chip,
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            const Icon(Icons.event_available_outlined, size: 17, color: AppColors.green),
            const SizedBox(width: 6),
            Expanded(child: Text('${shortDate(item.startsAt)} → ${shortDate(item.expiresAt)}', style: AppText.mono(size: 12, weight: FontWeight.w600, color: AppColors.textSecondary))),
            Text(money(item.amount), style: AppText.currency.copyWith(color: AppColors.blue)),
          ]),
        ),
        if (item.reminderSentAt != null) ...[
          const SizedBox(height: 6),
          Text('✓ Recordatorio enviado por WhatsApp', style: AppText.sans(size: 11.5, weight: FontWeight.w600, color: AppColors.green)),
        ],
      ]),
    );
  }
}
