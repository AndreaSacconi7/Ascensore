import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../authentication_state.dart';
import '../ui/components.dart';
import '../ui/game_widgets.dart';
import '../ui/theme.dart';
import 'offline_sheet.dart';
import '../state/session_controller.dart';
import 'loading_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoginMode = true;
  bool _obscurePassword = true;

  // True after the user submits the form, so a pending check shows in the button, not as a splash
  bool _submitted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionController>().checkLoginStatus();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit(SessionController manager) {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Inserisci email e password.');
      return;
    }
    setState(() {
      _error = null;
      _submitted = true;
    });
    if (_isLoginMode) {
      manager.loginWithEmail(email, password);
    } else {
      manager.signUpWithEmail(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<SessionController>();
    final loading = manager.authState == AuthenticationState.loading;

    // Take a pending error from the manager and keep it next to the form
    if (manager.authError != null) {
      final error = manager.authError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _error = error);
        manager.clearAuthError();
      });
    }

    // Resuming a saved session: the loading screen, no form flashing
    if (!_submitted && (loading || manager.authState == AuthenticationState.unknown)) {
      return const LoadingScreen();
    }

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: DecorativeCardFan(cardWidth: 64)),
                const SizedBox(height: 24),
                const Center(child: AppLogo(height: 42)),
                const SizedBox(height: 10),
                Text(
                  'Da 1 a 10 carte e ritorno: scommetti, gioca, sali.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ModeSwitch(
                        isLoginMode: _isLoginMode,
                        onChanged: (login) => setState(() {
                          _isLoginMode = login;
                          _error = null;
                        }),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Email',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _submit(manager),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword ? 'Mostra password' : 'Nascondi password',
                            icon: Icon(_obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        _ErrorText(_error!),
                      ],
                      const SizedBox(height: 20),
                      AppButton(
                        label: _isLoginMode ? 'ACCEDI' : 'CREA ACCOUNT',
                        loading: loading && _submitted,
                        onPressed: () => _submit(manager),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Gioca offline contro i bot',
                  icon: Icons.smart_toy_rounded,
                  style: AppButtonStyle.ghost,
                  onPressed: () => showOfflineSheet(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  final bool isLoginMode;
  final ValueChanged<bool> onChanged;

  const _ModeSwitch({required this.isLoginMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          _segment('Accedi', isLoginMode, () => onChanged(true)),
          _segment('Registrati', !isLoginMode, () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceStrong : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String message;

  const _ErrorText(this.message);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
      ],
    );
  }
}
