import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';

class _Tab {
  final String path;
  final String label;
  final IconData icon;
  const _Tab(this.path, this.label, this.icon);
}

const _tabs = [
  _Tab('/inicio', 'Inicio', Icons.space_dashboard_outlined),
  _Tab('/entrada', 'Entrada', Icons.add_circle_outline),
  _Tab('/salidas', 'Salidas', Icons.payments_outlined),
  _Tab('/mensual', 'Mensual', Icons.badge_outlined),
  _Tab('/caja', 'Caja', Icons.point_of_sale_outlined),
];

/// Estructura comun: encabezado con logo y barra de navegacion inferior.
class MainShell extends ConsumerWidget {
  final String location;
  final Widget child;
  const MainShell({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final index = _tabs.indexWhere((tab) => location.startsWith(tab.path));
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        titleSpacing: 16,
        title: Row(children: [
          const BrandLogo(height: 30),
          const SizedBox(width: 10),
          Container(width: 1, height: 26, color: AppColors.border),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_title(), style: AppText.sans(size: 16, weight: FontWeight.w800)),
              Text(auth.tenant?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small),
            ]),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: 'Menú',
            icon: const Icon(Icons.account_circle_outlined, size: 28),
            onPressed: () => _openMenu(context, ref),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: child,
      bottomNavigationBar: _BottomNav(index: index, onTap: (i) => context.go(_tabs[i].path)),
    );
  }

  static const _titles = {
    '/inicio': 'SP Parqueaderos',
    '/entrada': 'Nueva Entrada',
    '/salidas': 'Salida y Cobro',
    '/mensual': 'Mensualidades',
    '/caja': 'Caja del Día',
    '/configuracion': 'Configuración',
    '/auditoria': 'Auditoría',
  };

  String _title() => _titles.entries.where((entry) => location.startsWith(entry.key)).firstOrNull?.value ?? 'SP Parqueaderos';

  /// Menu de cuenta: datos del usuario, secciones de administracion y sesion.
  void _openMenu(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authProvider);
    final canManage = auth.tenant?.canManage == true;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheet) {
        void go(String path) {
          Navigator.pop(sheet);
          context.go(path);
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(_initials(auth.user?.fullName), style: AppText.sans(size: 16, weight: FontWeight.w800, color: AppColors.primary)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(auth.user?.fullName ?? '', style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(auth.user?.email ?? '', style: AppText.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                StatusChip.blue(auth.tenant?.roleLabel ?? ''),
              ]),
              const SizedBox(height: 16),
              if (canManage) ...[
                Text('ADMINISTRACIÓN', style: AppText.meta),
                const SizedBox(height: 6),
                _MenuItem(icon: Icons.tune, label: 'Configuración', detail: 'Tarifas por tipo de vehículo', onTap: () => go('/configuracion')),
                _MenuItem(icon: Icons.manage_search, label: 'Auditoría', detail: 'Quién hizo qué y cuándo', onTap: () => go('/auditoria')),
                const SizedBox(height: 10),
              ],
              Text('CUENTA', style: AppText.meta),
              const SizedBox(height: 6),
              if (auth.tenants.length > 1) _MenuItem(icon: Icons.swap_horiz, label: 'Cambiar de parqueadero', onTap: () => go('/parqueaderos')),
              _MenuItem(
                icon: Icons.logout,
                label: 'Cerrar sesión',
                danger: true,
                onTap: () {
                  Navigator.pop(sheet);
                  ref.read(authProvider).logout();
                },
              ),
            ]),
          ),
        );
      },
    );
  }

  static String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? detail;
  final bool danger;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, this.detail, this.danger = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.primary : AppColors.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SpCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: onTap,
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: danger ? AppColors.primaryLight : AppColors.subtle, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(icon, size: 19, color: danger ? AppColors.primary : AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppText.sans(size: 14, weight: FontWeight.w700, color: color)),
              if (detail != null) Text(detail!, style: AppText.small),
            ]),
          ),
          if (!danger) const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(_tabs[i].icon, size: 25, color: i == index ? AppColors.primary : AppColors.textMuted),
                    const SizedBox(height: 4),
                    Text(_tabs[i].label.toUpperCase(),
                        style: AppText.mono(size: 10, weight: FontWeight.w700, color: i == index ? AppColors.primary : AppColors.textMuted, letterSpacing: 0.5)),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
