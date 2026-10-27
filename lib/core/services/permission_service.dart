import 'package:permission_handler/permission_handler.dart';

enum AppPermissionType {
  camera,
  locationWhenInUse,
  photos,
}

enum AppPermissionState {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
}

class AppPermissionResult {
  const AppPermissionResult({
    required this.state,
    required this.message,
  });

  final AppPermissionState state;
  final String message;

  bool get isGranted =>
      state == AppPermissionState.granted ||
      state == AppPermissionState.limited;
}

class DevicePermissionService {
  Future<AppPermissionResult> ensureCameraPermission() {
    return _ensurePermission(
      permission: Permission.camera,
      type: AppPermissionType.camera,
    );
  }

  Future<AppPermissionResult> ensureLocationWhenInUsePermission() {
    return _ensurePermission(
      permission: Permission.locationWhenInUse,
      type: AppPermissionType.locationWhenInUse,
    );
  }

  Future<AppPermissionResult> ensurePhotosPermission() {
    return _ensurePermission(
      permission: Permission.photos,
      type: AppPermissionType.photos,
    );
  }

  Future<bool> openSettings() {
    return openAppSettings();
  }

  Future<AppPermissionResult> _ensurePermission({
    required Permission permission,
    required AppPermissionType type,
  }) async {
    var status = await permission.status;
    if (!status.isGranted && !status.isLimited) {
      status = await permission.request();
    }
    return _mapStatus(type, status);
  }

  AppPermissionResult _mapStatus(
    AppPermissionType type,
    PermissionStatus status,
  ) {
    if (status.isGranted) {
      return AppPermissionResult(
        state: AppPermissionState.granted,
        message: _grantedMessage(type),
      );
    }
    if (status.isLimited) {
      return AppPermissionResult(
        state: AppPermissionState.limited,
        message: _limitedMessage(type),
      );
    }
    if (status.isPermanentlyDenied) {
      return AppPermissionResult(
        state: AppPermissionState.permanentlyDenied,
        message: _permanentlyDeniedMessage(type),
      );
    }
    if (status.isRestricted) {
      return AppPermissionResult(
        state: AppPermissionState.restricted,
        message: _restrictedMessage(type),
      );
    }
    return AppPermissionResult(
      state: AppPermissionState.denied,
      message: _deniedMessage(type),
    );
  }

  String _grantedMessage(AppPermissionType type) {
    switch (type) {
      case AppPermissionType.camera:
        return 'Camera access granted.';
      case AppPermissionType.locationWhenInUse:
        return 'Location access granted.';
      case AppPermissionType.photos:
        return 'Photos access granted.';
    }
  }

  String _limitedMessage(AppPermissionType type) {
    switch (type) {
      case AppPermissionType.camera:
        return 'Camera access granted with limited availability.';
      case AppPermissionType.locationWhenInUse:
        return 'Location access granted with limited availability.';
      case AppPermissionType.photos:
        return 'Photos access granted with limited access.';
    }
  }

  String _deniedMessage(AppPermissionType type) {
    switch (type) {
      case AppPermissionType.camera:
        return 'Camera access is required to scan QR codes.';
      case AppPermissionType.locationWhenInUse:
        return 'Location access will be required to show live transport tracking.';
      case AppPermissionType.photos:
        return 'Photos access will be required when selecting or sharing images.';
    }
  }

  String _permanentlyDeniedMessage(AppPermissionType type) {
    switch (type) {
      case AppPermissionType.camera:
        return 'Camera access was blocked. Open app settings to enable it.';
      case AppPermissionType.locationWhenInUse:
        return 'Location access was blocked. Open app settings to enable it later.';
      case AppPermissionType.photos:
        return 'Photos access was blocked. Open app settings to enable it later.';
    }
  }

  String _restrictedMessage(AppPermissionType type) {
    switch (type) {
      case AppPermissionType.camera:
        return 'Camera access is restricted on this device.';
      case AppPermissionType.locationWhenInUse:
        return 'Location access is restricted on this device.';
      case AppPermissionType.photos:
        return 'Photos access is restricted on this device.';
    }
  }
}
