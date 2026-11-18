import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';

/// Registro: crea el usuario y su propio parqueadero, del que queda como propietario (OWNER).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _parking = TextEditingController();
  final _address = TextEditingController();
  bool _hidden = true;
  bool _accepted = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final controller in [_name, _email, _password, _confirm, _parking, _address]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 0 a 4 segun largo, letras, numeros y simbolos. El servidor exige 8+ caracteres con letras y numeros.
  int get _strength {
    final value = _password.text;
    var score = 0;
    if (value.length >= 8) score++;
    if (RegExp('[A-Za-z]').hasMatch(value) && RegExp(r'\d').hasMatch(value)) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    return score;
  }

  String? _validate() {
    if (_name.text.trim().isEmpty) return 'Ingresa tu nombre';
    if (!_email.text.contains('@')) return 'Ingresa un correo válido';
    if (_password.text.length < 8 || _strength < 2) return 'La contraseña debe tener al menos 8 caracteres, con letras y números';
    if (_password.text != _confirm.text) return 'Las contraseñas no coinciden';
    if (_parking.text.trim().isEmpty) return 'Ingresa el nombre del parqueadero';
    if (!_accepted) return 'Debes aceptar los términos para continuar';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final invalid = _validate();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider).register(
            fullName: _name.text,
            email: _email.text,
            password: _password.text,
            parkingName: _parking.text,
            branchAddress: _address.text,
          );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strength = _strength;
    final strengthColor = strength >= 3 ? AppColors.green : (strength == 2 ? AppColors.amber : AppColors.primary);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.go('/login')),
        titleSpacing: 0,
        title: Text('Volver', style: AppText.sans(size: 16, weight: FontWeight.w700)),
        actions: const [Padding(padding: EdgeInsets.only(right: 16), child: BrandLogo(height: 28))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          const Align(alignment: Alignment.centerLeft, child: StatusChip.blue('Nuevo parqueadero')),
          const SizedBox(height: 10),
          Text('Crear Cuenta', style: AppText.sans(size: 28, weight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text('Registra tu parqueadero y gestiona tu operación como Propietario.', style: AppText.sans(size: 14, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          SpCard(
            color: AppColors.primaryLight,
            borderColor: AppColors.primaryBorder,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.shield_outlined, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Rol de Propietario', style: AppText.title),
                  const SizedBox(height: 2),
                  Text('Tendrás control total de tarifas, caja, usuarios y reportes.', style: AppText.sans(size: 12, color: AppColors.textSecondary)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          SpCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('1. Datos del propietario', icon: Icons.person_outline, trailing: Text('PASO 1 DE 2', style: AppText.meta)),
              const FieldLabel('Nombre completo *'),
              TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(prefixIcon: Icon(Icons.badge_outlined), hintText: 'Juan Pérez')),
              const SizedBox(height: 12),
              const FieldLabel('Correo electrónico (login) *'),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(prefixIcon: Icon(Icons.alternate_email), hintText: 'gerencia@miparqueadero.com')),
              const SizedBox(height: 12),
              const FieldLabel('Contraseña de acceso *'),
              TextField(
                controller: _password,
                obscureText: _hidden,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline),
                  hintText: 'Mínimo 8 caracteres, letras y números',
                  suffixIcon: IconButton(icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hidden = !_hidden)),
                ),
              ),
              if (_password.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Text('SEGURIDAD DE CLAVE', style: AppText.meta),
                  const Spacer(),
                  Text(const ['MUY BAJA', 'BAJA', 'MEDIA', 'ALTA', 'ALTA'][strength], style: AppText.mono(size: 11, weight: FontWeight.w800, color: strengthColor)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      child: Container(
                        height: 5,
                        margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                        decoration: BoxDecoration(color: i < strength ? strengthColor : AppColors.subtle, borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                ]),
              ],
              const SizedBox(height: 12),
              const FieldLabel('Confirmar contraseña *'),
              TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(prefixIcon: Icon(Icons.verified_outlined), hintText: 'Repite la contraseña')),
            ]),
          ),
          const SizedBox(height: 16),
          SpCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('2. Datos del parqueadero', icon: Icons.local_parking, trailing: StatusChip.blue('Nuevo')),
              const FieldLabel('Nombre comercial *'),
              TextField(controller: _parking, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(prefixIcon: Icon(Icons.storefront_outlined), hintText: 'Parqueadero Central Plaza')),
              const SizedBox(height: 12),
              const FieldLabel('Ciudad y dirección de la sede'),
              TextField(controller: _address, decoration: const InputDecoration(prefixIcon: Icon(Icons.location_on_outlined), hintText: 'ej: Bogotá D.C. • Cra 7 #32-15')),
              const SizedBox(height: 8),
              Text('Los espacios, casilleros y tarifas los configuras después desde la web.', style: AppText.small),
            ]),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => setState(() => _accepted = !_accepted),
            child: SpCard(
              color: AppColors.subtle,
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Checkbox(value: _accepted, onChanged: (value) => setState(() => _accepted = value ?? false)),
                Expanded(child: Text('Acepto los Términos y Condiciones de Uso y la Política de Privacidad de Sistemas Palacios.', style: AppText.sans(size: 12, color: AppColors.textSecondary))),
              ]),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: AppText.sans(color: AppColors.primaryDark, weight: FontWeight.w600)),
          ],
          const SizedBox(height: 18),
          PrimaryButton(label: 'CREAR PARQUEADERO Y COMENZAR', icon: Icons.rocket_launch_outlined, large: true, loading: _loading, onPressed: _submit),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('¿Ya tienes una cuenta?', style: AppText.sans(size: 14, color: AppColors.textSecondary)),
            TextButton(onPressed: () => context.go('/login'), child: Text('Inicia sesión', style: AppText.sans(size: 14, weight: FontWeight.w800, color: AppColors.primaryDark))),
          ]),
        ],
      ),
    );
  }
}
