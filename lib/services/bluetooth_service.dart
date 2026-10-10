import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'permission_service.dart';

class BleDeviceReport {
  const BleDeviceReport({
    required this.id,
    required this.name,
    required this.rssi,
  });
  final String id;
  final String name;
  final int rssi;
}

String adapterDescription(BluetoothAdapterState state) => switch (state) {
  BluetoothAdapterState.on => 'Activado',
  BluetoothAdapterState.off =>
    'Apagado: actívalo desde los ajustes del teléfono',
  BluetoothAdapterState.turningOn => 'Activándose',
  BluetoothAdapterState.turningOff => 'Desactivándose',
  BluetoothAdapterState.unavailable => 'Adaptador no disponible',
  BluetoothAdapterState.unauthorized => 'Sin autorización Bluetooth',
  BluetoothAdapterState.unknown => 'Desconocido o todavía sin consultar',
};

abstract interface class BleGateway {
  Future<bool> isSupported();
  Stream<BluetoothAdapterState> get adapter;
  Stream<bool> get scanning;
  Stream<List<BleDeviceReport>> get results;
  Future<void> start();
  Future<void> stop();
}

class SystemBleGateway implements BleGateway {
  @override
  Future<bool> isSupported() => FlutterBluePlus.isSupported;
  @override
  Stream<BluetoothAdapterState> get adapter => FlutterBluePlus.adapterState;
  @override
  Stream<bool> get scanning => FlutterBluePlus.isScanning;
  @override
  Stream<List<BleDeviceReport>> get results =>
      FlutterBluePlus.onScanResults.map(
        (results) => results
            .map(
              (result) => BleDeviceReport(
                id: result.device.remoteId.str,
                name: result.advertisementData.advName.isNotEmpty
                    ? result.advertisementData.advName
                    : result.device.platformName,
                rssi: result.rssi,
              ),
            )
            .toList(),
      );
  @override
  Future<void> start() => FlutterBluePlus.startScan(
    timeout: const Duration(seconds: 12),
    // La app nunca deriva ubicación. En Android <=30 el SO exige su permiso.
    androidUsesFineLocation: false,
  );
  @override
  Future<void> stop() => FlutterBluePlus.stopScan();
}

class BluetoothService extends ChangeNotifier {
  BluetoothService({required this.permissions, BleGateway? gateway})
    : _gateway = gateway ?? SystemBleGateway() {
    permissions.addListener(_permissionsChanged);
  }
  final PermissionService permissions;
  final BleGateway _gateway;
  BluetoothAdapterState adapter = BluetoothAdapterState.unknown;
  bool? hardwareSupported;
  bool scanning = false;
  bool busy = false;
  bool attemptedScan = false;
  String? error;
  final Map<String, BleDeviceReport> _devices = {};
  List<BleDeviceReport> get devices =>
      _devices.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _disposed = false;
  bool _visible = false;
  bool _wanted = false;
  Future<void>? _initializing;
  Future<void>? _starting;
  Future<void>? _stopping;

  String? get blockedReason {
    if (!permissions.supported) {
      return 'El descubrimiento BLE está implementado para Android e iOS. No está disponible en esta plataforma o no se pudo consultar su versión.';
    }
    if (!permissions.granted) {
      return 'Falta autorización: solicita los permisos necesarios para descubrir BLE.';
    }
    if (hardwareSupported == false) {
      return 'Este dispositivo no admite Bluetooth BLE.';
    }
    if (hardwareSupported == null) {
      return 'Comprobando disponibilidad del adaptador.';
    }
    if (adapter != BluetoothAdapterState.on) return adapterDescription(adapter);
    return null;
  }

  bool get canScan =>
      _visible &&
      !busy &&
      !permissions.busy &&
      !scanning &&
      _stopping == null &&
      blockedReason == null;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _permissionsChanged() {
    if (_disposed) return;
    if (!permissions.granted) {
      adapter = BluetoothAdapterState.unknown;
      unawaited(stop());
    } else if (_visible) {
      unawaited(initialize());
    }
    _notify();
  }

  Future<void> activate() async {
    if (_disposed) return;
    _visible = true;
    error = null;
    await permissions.refresh();
    if (!_disposed && _visible) await initialize();
  }

  void deactivate() {
    _visible = false;
    unawaited(stop());
  }

  Future<void> initialize() {
    if (_disposed || !permissions.granted) return Future.value();
    if (_initializing != null) return _initializing!;
    _initializing = _initialize().whenComplete(() => _initializing = null);
    return _initializing!;
  }

  Future<void> _initialize() async {
    try {
      // No se inicializa CoreBluetooth sin permiso: podría mostrar una solicitud.
      hardwareSupported = await _gateway.isSupported().timeout(
        const Duration(seconds: 5),
      );
      if (_disposed || !permissions.granted || hardwareSupported != true) {
        return;
      }
      if (_subscriptions.isEmpty) {
        _subscriptions.add(
          _gateway.adapter.listen((state) {
            if (_disposed || !permissions.granted) return;
            adapter = state;
            if (state != BluetoothAdapterState.on) unawaited(stop());
            _notify();
          }, onError: _streamError),
        );
        _subscriptions.add(
          _gateway.scanning.listen((value) {
            if (_disposed) return;
            scanning = value;
            _notify();
          }, onError: _streamError),
        );
        _subscriptions.add(
          _gateway.results.listen((results) {
            if (_disposed || !_visible || !_wanted) return;
            for (final device in results) {
              _devices[device.id] = device;
            }
            _notify();
          }, onError: _streamError),
        );
      }
      // Reconsulta al volver de ajustes, incluso si la escucha ya estaba creada.
      final current = await _gateway.adapter.first.timeout(
        const Duration(seconds: 5),
      );
      if (!_disposed && permissions.granted) {
        adapter = current;
      }
    } catch (_) {
      if (!_disposed) {
        hardwareSupported = null;
        error =
            'No se pudo consultar Bluetooth. Revisa los permisos y vuelve a comprobar.';
      }
    } finally {
      _notify();
    }
  }

  void _streamError(Object failure) {
    if (_disposed) return;
    adapter = BluetoothAdapterState.unknown;
    error =
        'Bluetooth informó un error. Revisa permisos, adaptador y ubicación en Android 6–11.';
    unawaited(stop());
    _notify();
  }

  Future<void> start() {
    if (!canScan || _starting != null || _stopping != null) {
      return Future.value();
    }
    _wanted = true;
    busy = true;
    error = null;
    _devices.clear();
    attemptedScan = true;
    // El candado se fija antes de notificar para impedir reentradas.
    final completion = Completer<void>();
    _starting = completion.future;
    _notify();
    unawaited(_start(completion));
    return completion.future;
  }

  Future<void> _start(Completer<void> completion) async {
    try {
      await permissions.refresh();
      if (!_wanted || _disposed || !_visible || !permissions.granted) return;
      await initialize();
      if (!_wanted || _disposed || !_visible) return;
      if (blockedReason != null) {
        error = blockedReason;
        return;
      }
      await _gateway.start();
      // Una salida de pantalla mientras se iniciaba también cancela el escaneo.
      if (!_wanted || _disposed || !_visible || !permissions.granted) {
        await _gateway.stop();
      }
    } catch (_) {
      if (!_disposed) {
        error =
            'No se pudo iniciar el escaneo. Revisa Bluetooth, permisos y los servicios de ubicación en Android 6–11.';
      }
      try {
        await _gateway.stop();
      } catch (_) {
        /* Se conserva el error original. */
      }
    } finally {
      busy = false;
      _starting = null;
      completion.complete();
      _notify();
    }
  }

  Future<void> stop() {
    _wanted = false;
    if (_stopping != null) return _stopping!;
    // Sin inicialización no se toca el plugin (especialmente en Web/iOS).
    if (_subscriptions.isEmpty && _starting == null) return Future.value();
    _stopping = _stop().whenComplete(() {
      _stopping = null;
      _notify();
    });
    return _stopping!;
  }

  Future<void> _stop() async {
    try {
      if (_starting != null) await _starting;
      await _gateway.stop();
    } catch (_) {
      if (!_disposed) {
        error =
            'No se pudo confirmar la detención del escaneo. La búsqueda tiene un límite de 12 segundos.';
      }
    } finally {
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _visible = false;
    permissions.removeListener(_permissionsChanged);
    unawaited(stop());
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
