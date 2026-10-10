import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:conectalab/services/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'connectivity_fakes.dart';

void main() {
  test('Clasifica none, desconocido y todos los transportes simultáneos', () {
    expect(TransportReport([ConnectivityResult.none]).noNetwork, isTrue);
    expect(TransportReport([]).unknown, isTrue);
    expect(TransportReport(null).reports(ConnectivityResult.mobile), isNull);
    final report = TransportReport([
      ConnectivityResult.wifi,
      ConnectivityResult.mobile,
      ConnectivityResult.vpn,
      ConnectivityResult.ethernet,
      ConnectivityResult.wifi,
    ]);
    expect(report.description, 'Wi-Fi + Celular + VPN + Ethernet');
    expect(report.reports(ConnectivityResult.mobile), isTrue);
    expect(
      TransportReport([ConnectivityResult.other]).description,
      'Otro transporte',
    );
    expect(
      TransportReport([
        ConnectivityResult.none,
        ConnectivityResult.wifi,
      ]).contradictory,
      isTrue,
    );
    expect(
      TransportReport([
        ConnectivityResult.none,
        ConnectivityResult.wifi,
      ]).reports(ConnectivityResult.wifi),
      isNull,
    );
  });

  test('Web no presenta la estimación wifi como transporte físico', () {
    final report = TransportReport([ConnectivityResult.wifi], isWeb: true);
    expect(report.reports(ConnectivityResult.wifi), isNull);
    expect(report.description, contains('transporte físico desconocido'));
  });

  for (final code in [204, 404, 503]) {
    test('Una respuesta HTTP $code demuestra comunicación', () async {
      final probe = HttpHttpsProbe(
        client: MockClient((request) async {
          expect(request.url.scheme, 'https');
          expect(request.method, 'GET');
          expect(request.body, isEmpty);
          expect(request.url.queryParameters, contains('_conectalab_check'));
          return http.Response('', code);
        }),
      );
      addTearDown(probe.dispose);
      final result = await probe.check();
      expect(result.status, HttpsStatus.response);
      expect(result.code, code);
      expect(result.elapsed, isNotNull);
      expect(result.checkedAt, isNotNull);
    });
  }

  test('Timeout y fallo son distintos de una respuesta HTTP', () async {
    final delayed = Completer<http.Response>();
    final timeoutProbe = HttpHttpsProbe(
      client: MockClient((_) => delayed.future),
      timeout: const Duration(milliseconds: 10),
    );
    expect((await timeoutProbe.check()).status, HttpsStatus.timeout);
    delayed.complete(http.Response('', 204));
    timeoutProbe.dispose();
    final failing = HttpHttpsProbe(
      client: MockClient((_) async => throw http.ClientException('DNS')),
    );
    expect((await failing.check()).status, HttpsStatus.failed);
    failing.dispose();
    expect(
      () => HttpHttpsProbe(endpoint: Uri.parse('http://example.com')),
      throwsArgumentError,
    );
  });

  test(
    'Sin transporte también puede intentarse HTTPS; no se inventa un fallo',
    () async {
      final source = FakeNetworkSource()..values = [ConnectivityResult.none];
      final probe = FakeHttpsProbe();
      final service = ConnectivityService(
        source: source,
        probe: probe,
        isWeb: false,
      );
      await service.refresh();
      expect(service.transport.noNetwork, isTrue);
      expect(service.https.status, HttpsStatus.response);
      source.fail = true;
      await service.refresh();
      expect(service.transport.unknown, isTrue);
      expect(service.transportError, isNotNull);
      expect(service.https.status, HttpsStatus.response);
      service.dispose();
      await source.controller.close();
    },
  );

  test('Agrupa eventos, descarta prueba antigua y cancela recursos', () async {
    final source = FakeNetworkSource();
    final probe = FakeHttpsProbe()..pending = Completer<HttpsResult>();
    final service = ConnectivityService(
      source: source,
      probe: probe,
      isWeb: false,
      debounce: const Duration(milliseconds: 5),
    );
    service.start();
    await Future<void>.delayed(Duration.zero);
    final first = service.refresh();
    final repeated = service.refresh();
    expect(identical(first, repeated), isTrue);
    expect(probe.calls, 1);
    source.emit([ConnectivityResult.mobile]);
    source.emit([ConnectivityResult.mobile, ConnectivityResult.vpn]);
    source.emit([ConnectivityResult.vpn, ConnectivityResult.mobile]);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(probe.calls, 1);
    final pending = probe.pending!;
    probe.pending = null;
    pending.complete(const HttpsResult(HttpsStatus.response, code: 503));
    await first;
    await Future<void>.delayed(Duration.zero);
    expect(probe.calls, 2);
    expect(service.https.code, 204);
    expect(service.transport.reports(ConnectivityResult.mobile), isTrue);
    service.dispose();
    expect(source.controller.hasListener, isFalse);
    expect(probe.disposed, isTrue);
    await source.controller.close();
  });

  test(
    'Una operación tardía tras dispose no notifica widgets eliminados',
    () async {
      final source = FakeNetworkSource();
      final probe = FakeHttpsProbe()..pending = Completer<HttpsResult>();
      final service = ConnectivityService(source: source, probe: probe);
      var notifications = 0;
      service.addListener(() => notifications++);
      final operation = service.refresh();
      await Future<void>.delayed(Duration.zero);
      service.dispose();
      final count = notifications;
      probe.pending!.complete(const HttpsResult(HttpsStatus.failed));
      await operation;
      expect(notifications, count);
      await source.controller.close();
    },
  );

  test('Un error tardío no se atribuye al transporte nuevo', () async {
    final source = FakeNetworkSource();
    final probe = FakeHttpsProbe()..pending = Completer<HttpsResult>();
    final service = ConnectivityService(
      source: source,
      probe: probe,
      debounce: const Duration(seconds: 1),
    );
    service.start();
    await Future<void>.delayed(Duration.zero);
    final operation = service.refresh();
    source.emit([ConnectivityResult.mobile]);
    probe.pending!.completeError(StateError('Fallo de la red anterior'));
    await operation;
    expect(service.https.status, HttpsStatus.notChecked);
    expect(service.lastCheckedAt, isNull);
    service.dispose();
    await source.controller.close();
  });
}
