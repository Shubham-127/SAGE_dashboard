import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/enums.dart';
import '../state/sage_state.dart';
import '../widgets/panel.dart';
import '../widgets/pill.dart';

/// First screen. In the real project Keycloak does this job
/// (it checks who you are and gives you a role).
/// Here two buttons simply set the role to Admin or Viewer.
class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Panel(
              child: SizedBox(
                width: double.infinity,
                child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  const Icon(Icons.shield_outlined, size: 46, color: AppColors.accent),
                  const SizedBox(height: 10),
                  const Text('SAGE',
                      style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6,
                          color: AppColors.text)),
                  const SizedBox(height: 6),
                  const Text('Self-healing Agent for Graceful Error-recovery',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => sage.login(Role.admin),
                      child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Sign in as Admin')),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => sage.login(Role.viewer),
                      child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Sign in as Viewer')),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Admins can inject faults and approve or dismiss fixes.\nViewers can only watch.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  const Pill('Prototype login: Keycloak replaces this', AppColors.warn,
                      icon: Icons.science_outlined),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
