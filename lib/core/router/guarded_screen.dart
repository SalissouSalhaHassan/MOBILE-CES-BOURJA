import 'package:flutter/material.dart';

import '../di/injection.dart';
import '../permissions/permission_service.dart';

class GuardedScreen extends StatelessWidget {
  const GuardedScreen({
    super.key,
    required this.permission,
    required this.child,
  });

  final String permission;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final service = locator<PermissionService>();
    return FutureBuilder<bool>(
      future: service.hasPermission(permission),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true) {
          return child;
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Acces refuse')),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Vous n avez pas la permission necessaire pour ouvrir cette page.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}
