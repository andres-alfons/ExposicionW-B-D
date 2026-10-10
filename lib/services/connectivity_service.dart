import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Conserva todos los transportes; una lista vacía no equivale a `none`.
class TransportReport {
  TransportReport(List<ConnectivityResult>? results, {this.isWeb = false})
    : values = results == null ? null : Set.unmodifiable(results);

  final Set<ConnectivityResult>? values;
  final bool isWeb;
  bool get unknown => values == null || values!.isEmpty;
  bool get noNetwork =>
      values?.length == 1 && values!.contains(ConnectivityResult.none);
  bool get contradictory =>
      (values?.length ?? 0) > 1 && values!.contains(ConnectivityResult.none);

  bool? reports(ConnectivityResult transport) {
    if (unknown || isWeb || contradictory) return null;
    return values!.contains(transport);
  }

  String get description {
    if (unknown) return 'Desconocido o no concluyente';
    if (isWeb) {
      return noNetwork
          ? 'El navegador estima ausencia de conexión; transporte físico desconocido'
          : 'El navegador estima conectividad; transporte físico desconocido';
    }
    if (noNetwork) return 'Sin transporte de red reportado';
    final names = values!
        .where((v) => v != ConnectivityResult.none)
        .map(
          (v) => switch (v) {
            ConnectivityResult.wifi => 'Wi-Fi',
            ConnectivityResult.mobile => 'Celular',
            ConnectivityResult.ethernet => 'Ethernet',
            ConnectivityResult.vpn => 'VPN',
            ConnectivityResult.bluetooth => 'Bluetooth (transporte de red)',
            ConnectivityResult.satellite => 'Satélite',
            ConnectivityResult.other => 'Otro transporte',
            ConnectivityResult.none => 'Sin transporte',
          },
        )
        .join(' + ');
    return contradictory ? '$names · reporte no concluyente' : names;
  }
}

enum HttpsStatus { notChecked, checking, response, timeout, failed }

class HttpsResult {
  const HttpsResult(this.status, {this.code, this.elapsed, this.checkedAt});
  final HttpsStatus status;
  final int? code;
  final Duration? elapsed;
  final DateTime? checkedAt;

  String get description => switch (status) {
    HttpsStatus.notChecked => 'Todavía sin comprobar',
    HttpsStatus.checking => 'Comprobando acceso HTTPS…',
    HttpsStatus.response =>
      code! >= 200 && code! < 300
          ? 'Acceso al servidor verificado · HTTP $code'
          : 'Comunicación verificada · el servidor respondió HTTP $code',
    HttpsStatus.timeout => 'El servidor no respondió dentro del tiempo límite.',
    HttpsStatus.failed => 'No se pudo completar la petición HTTPS.',
  };
}

abstract interface class NetworkSource {
  Future<List<ConnectivityResult>> check();
  Stream<List<ConnectivityResult>> get changes;
}

class SystemNetworkSource implements NetworkSource {
  final Connectivity _connectivity = Connectivity();
  @override
  Future<List<ConnectivityResult>> check() => _connectivity.checkConnectivity();
  @override
  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}

abstract interface class HttpsProbe {
  Future<HttpsResult> check();
  void dispose();
}

class HttpHttpsProbe implements HttpsProbe {
  HttpHttpsProbe({
    http.Client? client,
    Uri? endpoint,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       endpoint =
           endpoint ??
           Uri.parse(
             const String.fromEnvironment(
               'CONNECTALAB_HTTPS_ENDPOINT',
               defaultValue: 'https://httpbin.org/status/204',
             ),
           ) {
    if (this.endpoint.scheme != 'https' ||
        this.endpoint.host.isEmpty ||
        this.endpoint.userInfo.isNotEmpty) {
      throw ArgumentError(
        'El endpoint debe ser una URL HTTPS sin credenciales.',
      );
    }
  }

  final http.Client _client;
  final Uri endpoint;
  final Duration timeout;
  Completer<void>? _abort;
  bool _disposed = false;

  @override
  Future<HttpsResult> check() async {
    if (_disposed) return const HttpsResult(HttpsStatus.failed);
    final abort = Completer<void>();
    _abort = abort;
    final watch = Stopwatch()..start();
    // Evita que una respuesta en caché aparente una comprobación nueva.
    // Solo se envía una marca temporal, sin identificadores ni datos personales.
    final url = endpoint.replace(
      queryParameters: {
        ...endpoint.queryParameters,
        '_conectalab_check': DateTime.now().microsecondsSinceEpoch.toString(),
      },
    );
    try {
      final request = http.AbortableRequest(
        'GET',
        url,
        abortTrigger: abort.future,
      )..followRedirects = false;
      final response = await _client.send(request).timeout(timeout);
      watch.stop();
      // Recibir cabeceras ya demuestra comunicación, incluso si el código es 4xx/5xx.
      // No descargamos ni conservamos el cuerpo del servidor.
      unawaited(response.stream.listen((_) {}).cancel());
      return HttpsResult(
        HttpsStatus.response,
        code: response.statusCode,
        elapsed: watch.elapsed,
        checkedAt: DateTime.now(),
      );
    } on TimeoutException {
      return HttpsResult(HttpsStatus.timeout, checkedAt: DateTime.now());
    } catch (_) {
      return HttpsResult(HttpsStatus.failed, checkedAt: DateTime.now());
    } finally {
      watch.stop();
      if (!abort.isCompleted) abort.complete();
      if (identical(_abort, abort)) _abort = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_abort != null && !_abort!.isCompleted) _abort!.complete();
    _client.close();
  }
}

/// Una instancia compartida evita duplicar escuchas y peticiones entre pantallas.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService({
    NetworkSource? source,
    HttpsProbe? probe,
    bool isWeb = kIsWeb,
    this.debounce = const Duration(milliseconds: 600),
  }) : _source = source ?? SystemNetworkSource(),
       _probe = probe ?? HttpHttpsProbe(),
       transport = TransportReport(null, isWeb: isWeb);

  final NetworkSource _source;
  final HttpsProbe _probe;
  final Duration debounce;
  TransportReport transport;
  HttpsResult https = const HttpsResult(HttpsStatus.notChecked);
  DateTime? lastCheckedAt;
  String? transportError;
  bool busy = false;
  bool _disposed = false;
  bool _started = false;
  bool _pendingChange = false;
  int _revision = 0;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounceTimer;
  Future<void>? _running;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _subscription = _source.changes.listen(
      _onChange,
      onError: (Object error) {
        if (_disposed) return;
        _revision++;
        transport = TransportReport(null, isWeb: transport.isWeb);
        https = const HttpsResult(HttpsStatus.notChecked);
        transportError =
            'No se pudieron escuchar los cambios de red. Puedes actualizar manualmente.';
        notifyListeners();
      },
    );
    unawaited(refresh());
  }

  void _onChange(List<ConnectivityResult> results) {
    if (_disposed || setEquals(transport.values, results.toSet())) return;
    _revision++;
    transport = TransportReport(results, isWeb: transport.isWeb);
    transportError = null;
    https = const HttpsResult(HttpsStatus.notChecked);
    notifyListeners();
    _pendingChange = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      _debounceTimer = null;
      if (!busy) unawaited(refresh());
    });
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    if (_running != null) return _running!;
    _pendingChange = false;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    // Se fija el candado antes de notificar para evitar reentradas desde la UI.
    final completion = Completer<void>();
    _running = completion.future;
    busy = true;
    https = const HttpsResult(HttpsStatus.checking);
    notifyListeners();
    unawaited(_refresh(completion));
    return completion.future;
  }

  Future<void> _refresh(Completer<void> completion) async {
    int? probeRevision;
    try {
      final beforeQuery = _revision;
      try {
        final values = await _source.check().timeout(
          const Duration(seconds: 5),
        );
        if (_disposed) return;
        // Un evento más reciente prevalece sobre una consulta inicial tardía.
        if (beforeQuery == _revision) {
          transport = TransportReport(values, isWeb: transport.isWeb);
          transportError = null;
        }
      } catch (_) {
        if (_disposed) return;
        if (beforeQuery == _revision) {
          transport = TransportReport(null, isWeb: transport.isWeb);
          transportError = 'No se pudo consultar el transporte de red.';
        }
      }
      if (_disposed) return;
      final beforeProbe = _revision;
      probeRevision = beforeProbe;
      // Los cambios recibidos durante la consulta quedan incluidos en esta prueba.
      _pendingChange = false;
      _debounceTimer?.cancel();
      _debounceTimer = null;
      notifyListeners();
      final result = await _probe.check();
      if (!_disposed && beforeProbe == _revision) {
        https = result;
        lastCheckedAt = result.checkedAt;
      }
    } catch (_) {
      // Un fallo tardío tampoco debe reemplazar el diagnóstico de una red nueva.
      if (!_disposed && probeRevision == _revision) {
        lastCheckedAt = DateTime.now();
        https = HttpsResult(HttpsStatus.failed, checkedAt: lastCheckedAt);
      }
    } finally {
      busy = false;
      _running = null;
      completion.complete();
      if (!_disposed) {
        notifyListeners();
        // Agrupa cambios consecutivos y descarta resultados de la red anterior.
        if (_pendingChange && _debounceTimer == null) unawaited(refresh());
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    unawaited(_subscription?.cancel());
    _probe.dispose();
    super.dispose();
  }
}
