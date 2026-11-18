import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';

/// Se muestra cuando el usuario pertenece a varios parqueaderos.
class TenantPickerScreen extends ConsumerWidget {
  const TenantPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(
        title: const BrandLogo(height: 30),
        actions: [TextButton(onPressed: () => ref.read(authProvider).logout(), child: const Text('Salir'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Elige el parqueadero', style: AppText.display),
          const SizedBox(height: 4),
          Text('Hola ${auth.user?.fullName ?? ''}, perteneces a varios parqueaderos.', style: AppText.sans(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          if (auth.tenants.isEmpty)
            const ErrorPanel('Tu cuenta no pertenece a ningún parqueadero. Pide al propietario que te agregue a su equipo.'),
          for (final tenant in auth.tenants)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SpCard(
                borderColor: tenant.uuid == auth.tenantUuid ? AppColors.primaryBorder : AppColors.border,
                onTap: () async {
                  await ref.read(authProvider).selectTenant(tenant.uuid);
                  if (context.mounted) context.go('/inicio');
                },
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: const Icon(Icons.local_parking, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tenant.name, style: AppText.title),
                      Text(tenant.roleLabel, style: AppText.small),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
