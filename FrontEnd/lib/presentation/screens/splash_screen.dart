import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final restoreError = auth.sessionRestoreError;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFD7F542),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.change_history_rounded, size: 42),
              ),
              const SizedBox(height: 14),
              const Text(
                'ADIDAS',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              if (restoreError == null) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 14),
                const Text('Đang khôi phục phiên đăng nhập...'),
              ] else ...[
                Text(restoreError.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: auth.isRestoring ? null : auth.restoreSession,
                  icon: auth.isRestoring
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('Thử kết nối lại'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
