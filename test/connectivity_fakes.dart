import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:conectalab/services/connectivity_service.dart';

class FakeNetworkSource implements NetworkSource {
  List<ConnectivityResult> values = [ConnectivityResult.wifi];
  bool fail = false;
  final controller = StreamController<List<ConnectivityResult>>.broadcast(
    sync: true,
  );
  @override
  Future<List<ConnectivityResult>> check() async {
    if (fail) throw StateError('Consulta no disponible');
    return values;
  }

  @override
  Stream<List<ConnectivityResult>> get changes => controller.stream;
  void emit(List<ConnectivityResult> next) {
    values = next;
    controller.add(next);
  }
}

class FakeHttpsProbe implements HttpsProbe {
  int calls = 0;
  bool disposed = false;
  Completer<HttpsResult>? pending;
  HttpsResult result = HttpsResult(
    HttpsStatus.response,
    code: 204,
    elapsed: const Duration(milliseconds: 25),
    checkedAt: DateTime(2026, 10, 9, 12),
  );
  @override
  Future<HttpsResult> check() async {
    calls++;
    return pending == null ? result : pending!.future;
  }

  @override
  void dispose() => disposed = true;
}
