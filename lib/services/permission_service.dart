import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

enum AppPermission { bluetooth, scan, connect, location, camera }

enum AccessState { unknown, granted, denied, settings, restricted, limited }

AccessState classifyPermission(ph.PermissionStatus value) => switch (value) {
  ph.PermissionStatus.granted => AccessState.granted,
  ph.PermissionStatus.denied => AccessState.denied,
  ph.PermissionStatus.permanentlyDenied => AccessState.settings,
  ph.PermissionStatus.restricted => AccessState.restricted,
  ph.PermissionStatus.limited ||
  ph.PermissionStatus.provisional => AccessState.limited,
};

String accessDescription(AccessState state) => switch (state) {
  AccessState.unknown => 'Desconocido o sin consultar',
  AccessState.granted => 'Concedido',
  // Android no distingue siempre una primera consulta de una denegación previa.
  AccessState.denied => 'Denegado o todavía no solicitado',
  AccessState.settings => 'Denegado permanentemente: revisa los ajustes',
  AccessState.restricted => 'Restringido por el sistema',
  AccessState.limited => 'Acceso limitado; no habilita esta función',
};

class PermissionPolicy {
  const PermissionPolicy(this.platform, {this.androidSdk, this.isWeb = false});
  final TargetPlatform platform;
  final int? androidSdk;
  final bool isWeb;
  bool get supported =>
      !isWeb &&
      (platform == TargetPlatform.iOS ||
          (platform == TargetPlatform.android && androidSdk != null));
  List<AppPermission> get requiredPermissions {
    if (!supported) return const [];
    if (platform == TargetPlatform.iOS) return const [AppPermission.bluetooth];
    if (androidSdk! >= 31) {
      return const [AppPermission.scan, AppPermission.connect];
    }
    if (androidSdk! >= 23) return const [AppPermission.location];
    return const [];
  }

  // Android captura mediante la app de cámara del sistema sin permiso CAMERA.
  // El selector de fotos concede acceso solo al archivo elegido, sin permiso global.
  List<AppPermission> get availablePermissions => [
    ...requiredPermissions,
    if (supported && platform == TargetPlatform.iOS) AppPermission.camera,
  ];
}

abstract interface class PermissionGateway {
  Future<PermissionPolicy> policy();
  Future<AccessState> check(AppPermission permission);
  Future<AccessState> request(AppPermission permission);
  Future<bool> openSettings();
}

class SystemPermissionGateway implements PermissionGateway {
  static const _channel = MethodChannel('conectalab/network_settings');
  ph.Permission _permission(AppPermission value) => switch (value) {
    AppPermission.bluetooth => ph.Permission.bluetooth,
    AppPermission.scan => ph.Permission.bluetoothScan,
    AppPermission.connect => ph.Permission.bluetoothConnect,
    AppPermission.location => ph.Permission.locationWhenInUse,
    AppPermission.camera => ph.Permission.camera,
  };
  @override
  Future<PermissionPolicy> policy() async => PermissionPolicy(
    defaultTargetPlatform,
    isWeb: kIsWeb,
    androidSdk: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? await _channel.invokeMethod<int>('sdkInt')
        : null,
  );
  @override
  Future<AccessState> check(AppPermission permission) async =>
      classifyPermission(await _permission(permission).status);
  @override
  Future<AccessState> request(AppPermission permission) async =>
      classifyPermission(await _permission(permission).request());
  @override
  Future<bool> openSettings() => ph.openAppSettings();
}

class PermissionService extends ChangeNotifier {
  PermissionService({PermissionGateway? gateway})
    : _gateway = gateway ?? SystemPermissionGateway();
  final PermissionGateway _gateway;
  PermissionPolicy? policy;
  final Map<AppPermission, AccessState> states = {};
  final Map<AppPermission, String> requestResults = {};
  bool busy = false;
  bool _disposed = false;
  String? error;
  List<AppPermission> get requiredPermissions =>
      policy?.requiredPermissions ?? const [];
  List<AppPermission> get availablePermissions =>
      policy?.availablePermissions ?? const [];
  bool get supported => policy?.supported == true;
  bool get granted =>
      supported &&
      requiredPermissions.every((p) => states[p] == AccessState.granted);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    _notify();
    try {
      final nextPolicy = await _gateway.policy();
      if (_disposed) return;
      policy = nextPolicy;
      for (final permission in availablePermissions) {
        final state = await _gateway.check(permission);
        if (_disposed) return;
        states[permission] = state;
      }
    } catch (_) {
      error =
          'No se pudieron consultar los permisos. Intenta comprobarlos otra vez.';
      states.clear();
      policy = null;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> request(AppPermission permission) async {
    if (busy || _disposed || !availablePermissions.contains(permission)) return;
    final previous = states[permission];
    if (previous == AccessState.granted ||
        previous == AccessState.settings ||
        previous == AccessState.restricted) {
      return;
    }
    busy = true;
    error = null;
    _notify();
    try {
      final result = await _gateway.request(permission);
      if (_disposed) return;
      states[permission] = result;
      requestResults[permission] =
          'Resultado: ${result == AccessState.denied ? 'Denegado' : accessDescription(result)}';
    } catch (_) {
      if (!_disposed) {
        states[permission] = AccessState.unknown;
        error =
            'No se pudo completar la solicitud. La función afectada seguirá deshabilitada.';
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> requestBluetooth() async {
    if (busy || _disposed) return;
    if (policy == null) await refresh();
    for (final permission in requiredPermissions) {
      await request(permission);
      // No encadena más ventanas después de una denegación.
      if (_disposed || states[permission] != AccessState.granted) break;
    }
  }

  Future<void> openSettings() async {
    if (!supported || busy || _disposed) return;
    try {
      if (!await _gateway.openSettings()) {
        error = 'No se pudieron abrir los ajustes. Ábrelos manualmente.';
      }
    } catch (_) {
      error = 'No se pudieron abrir los ajustes. Ábrelos manualmente.';
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

String permissionName(AppPermission permission) => switch (permission) {
  AppPermission.bluetooth => 'Bluetooth',
  AppPermission.scan => 'Bluetooth: descubrir dispositivos',
  AppPermission.connect => 'Bluetooth: consultar el adaptador',
  AppPermission.location => 'Ubicación para descubrimiento BLE',
  AppPermission.camera => 'Cámara para el chat local',
};
String permissionPurpose(AppPermission permission) => switch (permission) {
  AppPermission.bluetooth =>
    'Permite descubrir dispositivos BLE cercanos en iOS.',
  AppPermission.scan =>
    'Permite recibir anuncios BLE en Android 12 o posterior.',
  AppPermission.connect =>
    'Android exige este permiso para consultar el adaptador. Esta fase no conecta dispositivos.',
  AppPermission.location =>
    'Android 6–11 exige ubicación para descubrir BLE. La app no consulta coordenadas ni usa ubicación en segundo plano.',
  AppPermission.camera =>
    'Permite tomar una fotografía para previsualizarla y añadirla al chat local en iOS.',
};
