import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Tarjeta nivel 1: blanca, borde de 1px y sombra minima.
class SpCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final VoidCallback? onTap;
  const SpCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color = AppColors.card, this.borderColor = AppColors.border, this.onTap});

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
        boxShadow: const [BoxShadow(color: Color(0x0D0F172A), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(AppRadius.lg), onTap: onTap, child: body));
  }
}

/// Titulo de seccion con la barra roja vertical: | MAPA DE OCUPACION
class SectionTitle extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Widget? trailing;
  final Color barColor;
  const SectionTitle(this.text, {super.key, this.icon, this.trailing, this.barColor = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        if (icon != null) Icon(icon, size: 18, color: AppColors.primary) else Container(width: 4, height: 18, decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(child: Text(text.toUpperCase(), style: AppText.mono(size: 13, weight: FontWeight.w800, letterSpacing: 0.6))),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// Etiqueta pequena en mayusculas para campos: USUARIO O CORREO ELECTRONICO
class FieldLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const FieldLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Row(children: [
        Expanded(child: Text(text.toUpperCase(), style: AppText.mono(size: 11.5, weight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.6))),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// Placa amarilla colombiana con letra monoespaciada.
class PlateBadge extends StatelessWidget {
  final String plate;
  final bool large;
  final bool monthly;
  const PlateBadge(this.plate, {super.key, this.large = false, this.monthly = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 18 : 10, vertical: large ? 10 : 4),
      decoration: BoxDecoration(
        color: monthly ? Colors.white : AppColors.plateYellow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.ink, width: large ? 2.5 : 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(displayPlate(plate), style: AppText.mono(size: large ? 30 : 15, weight: FontWeight.w800, letterSpacing: 1.5, color: AppColors.ink)),
        if (large) Text('COLOMBIA', style: AppText.mono(size: 9, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: 1)),
      ]),
    );
  }
}

/// Boton principal rojo (Nueva Entrada, Cobrar / Salida...).
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool large;
  final Color color;
  const PrimaryButton({super.key, required this.label, this.icon, this.onPressed, this.loading = false, this.large = false, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: large ? 56 : 46,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          elevation: large ? 2 : 0,
        ),
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[Icon(icon, size: large ? 24 : 20), const SizedBox(width: 8)],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: AppText.sans(size: large ? 17 : 14, weight: FontWeight.w800, color: Colors.white))),
              ]),
      ),
    );
  }
}

/// Boton secundario blanco con borde (Imprimir, Cancelar...).
class GhostButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  const GhostButton({super.key, required this.label, this.icon, this.onPressed, this.color = AppColors.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: color,
          side: BorderSide(color: color == AppColors.text ? AppColors.borderStrong : color),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: AppText.sans(size: 14, weight: FontWeight.w700, color: color))),
        ]),
      ),
    );
  }
}

/// Chip de estado (PARQUEADERO ACTIVO, ADENTRO, MENSUALIDAD VIGENTE...).
class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  final Color border;
  final bool dot;
  const StatusChip(this.text, {super.key, this.color = AppColors.green, this.background = AppColors.greenLight, this.border = AppColors.greenBorder, this.dot = false});

  const StatusChip.red(this.text, {super.key, this.dot = false})
      : color = AppColors.primary,
        background = AppColors.primaryLight,
        border = AppColors.primaryBorder;

  const StatusChip.amber(this.text, {super.key, this.dot = false})
      : color = AppColors.amber,
        background = AppColors.amberLight,
        border = AppColors.amberBorder;

  const StatusChip.blue(this.text, {super.key, this.dot = false})
      : color = AppColors.blue,
        background = AppColors.blueLight,
        border = AppColors.blueBorder;

  const StatusChip.muted(this.text, {super.key, this.dot = false})
      : color = AppColors.textMuted,
        background = AppColors.subtle,
        border = AppColors.border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99), border: Border.all(color: border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6)],
        Text(text.toUpperCase(), style: AppText.mono(size: 10.5, weight: FontWeight.w700, color: color, letterSpacing: 0.4)),
      ]),
    );
  }
}

/// Tarjeta de indicador: etiqueta, valor grande y detalle.
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  final IconData? icon;
  final Color valueColor;
  final Color iconColor;
  final Widget? footer;
  const KpiCard({super.key, required this.label, required this.value, this.suffix, this.icon, this.valueColor = AppColors.text, this.iconColor = AppColors.primary, this.footer});

  @override
  Widget build(BuildContext context) {
    return SpCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label.toUpperCase(), style: AppText.meta, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (icon != null) Icon(icon, size: 17, color: iconColor),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: AppText.metric.copyWith(color: valueColor)))),
          if (suffix != null) ...[
            const SizedBox(width: 4),
            Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(suffix!, style: AppText.sans(size: 13, weight: FontWeight.w700, color: AppColors.textMuted))),
          ],
        ]),
        if (footer != null) ...[const SizedBox(height: 8), footer!],
      ]),
    );
  }
}

/// Barra de progreso de 4px (ocupacion).
class ProgressRail extends StatelessWidget {
  final double value;
  final Color color;
  const ProgressRail(this.value, {super.key, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(value: value.clamp(0, 1).toDouble(), minHeight: 5, color: color, backgroundColor: AppColors.subtle),
    );
  }
}

/// Logo de Sistemas Palacios (assets/img/logo-sistemas-palacios.jpg).
class BrandLogo extends StatelessWidget {
  final double height;
  const BrandLogo({super.key, this.height = 34});

  @override
  Widget build(BuildContext context) => Image.asset('assets/img/logo-sistemas-palacios.jpg', height: height, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
}

/// Mensaje de error con boton para reintentar.
class ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorPanel(this.message, {super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SpCard(
      color: AppColors.primaryLight,
      borderColor: AppColors.primaryBorder,
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.error_outline, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppText.sans(color: AppColors.primaryDark, weight: FontWeight.w600))),
        ]),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          GhostButton(label: 'Reintentar', icon: Icons.refresh, onPressed: onRetry, color: AppColors.primary),
        ],
      ]),
    );
  }
}

/// Fila etiqueta / valor alineada a la derecha (desglose de cobro, totales).
class AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const AmountRow(this.label, this.value, {super.key, this.valueColor = AppColors.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: AppText.mono(size: 12.5, weight: FontWeight.w500, color: AppColors.textSecondary))),
        const SizedBox(width: 12),
        Text(value, style: AppText.currency.copyWith(color: valueColor)),
      ]),
    );
  }
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: error ? AppColors.primaryBorder : AppColors.greenBorder),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
    ));
}

/// Aviso para el cajero: configuracion y auditoria son solo para propietario y administrador (igual que en la web).
class RestrictedPanel extends StatelessWidget {
  final String what;
  const RestrictedPanel(this.what, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SizedBox(height: 40),
      const Icon(Icons.lock_outline, size: 56, color: AppColors.textDisabled),
      const SizedBox(height: 12),
      Text('Acceso restringido', textAlign: TextAlign.center, style: AppText.headline),
      const SizedBox(height: 6),
      Text('$what solo está disponible para el propietario y los administradores del parqueadero.',
          textAlign: TextAlign.center, style: AppText.sans(color: AppColors.textMuted)),
    ]);
  }
}
