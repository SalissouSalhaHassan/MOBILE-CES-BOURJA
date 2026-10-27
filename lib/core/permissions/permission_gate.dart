import 'package:flutter/material.dart';

import '../di/injection.dart';
import 'permission_service.dart';

class PermissionGate extends StatelessWidget {
  const PermissionGate({
    super.key,
    this.permission,
    this.anyPermissions,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  final String? permission;
  final List<String>? anyPermissions;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final service = locator<PermissionService>();
    return FutureBuilder<bool>(
      future: _resolve(service),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        return snapshot.data == true ? child : fallback;
      },
    );
  }

  Future<bool> _resolve(PermissionService service) {
    if (permission != null) {
      return service.hasPermission(permission!);
    }
    if (anyPermissions != null && anyPermissions!.isNotEmpty) {
      return service.hasAnyPermission(anyPermissions!);
    }
    return Future.value(true);
  }
}
