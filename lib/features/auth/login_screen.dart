import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/config/env.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (ref.read(authProvider).takeExpiredNotice()) _error = 'Tu sesión expiró. Ingresa de nuevo.';
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Ingresa tu correo y tu contraseña');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider).login(_email.text, _password.text);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('SP PARQUEADEROS', style: AppText.mono(size: 11, weight: FontWeight.w800, color: AppColors.green)),
              const Spacer(),
              const Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('Conexión segura', style: AppText.mono(size: 11, color: AppColors.textMuted)),
            ]),
            const Divider(height: 20),
            const SizedBox(height: 28),
            const Center(
              child: SpCard(padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14), child: BrandLogo(height: 64)),
            ),
            const SizedBox(height: 14),
            const Center(
              child: StatusChip.blue('SP Parqueaderos'),
            ),
            const SizedBox(height: 12),
            Text('Iniciar Sesión', textAlign: TextAlign.center, style: AppText.sans(size: 28, weight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text('Sistema de Gestión y Control de Parqueaderos', textAlign: TextAlign.center, style: AppText.sans(color: AppColors.textMuted)),
            const SizedBox(height: 24),
            SpCard(
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const FieldLabel('Correo electrónico'),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.badge_outlined), hintText: 'cajero@miparqueadero.com'),
                  ),
                  const SizedBox(height: 14),
                  const FieldLabel('Contraseña'),
                  TextField(
                    controller: _password,
                    obscureText: _hidden,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline),
                      hintText: '••••••••',
                      suffixIcon: IconButton(
                        tooltip: _hidden ? 'Mostrar contraseña' : 'Ocultar contraseña',
                        icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _hidden = !_hidden),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: AppText.sans(color: AppColors.primaryDark, weight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 18),
                  PrimaryButton(label: 'INGRESAR AL SISTEMA', icon: Icons.login, loading: _loading, onPressed: _submit),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            SpCard(
              color: AppColors.blueLight,
              borderColor: AppColors.blueBorder,
              child: Column(children: [
                Text('¿No tienes cuenta para tu parqueadero?', style: AppText.sans(size: 14, color: AppColors.textSecondary)),
                TextButton(
                  onPressed: () => context.go('/registro'),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Regístrate aquí', style: AppText.sans(size: 16, weight: FontWeight.w800, color: AppColors.primaryDark)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, size: 18, color: AppColors.primaryDark),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 28),
            Text('Sistemas Palacios • ${Env.apiBaseUrl}', textAlign: TextAlign.center, style: AppText.mono(size: 11, weight: FontWeight.w500, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
