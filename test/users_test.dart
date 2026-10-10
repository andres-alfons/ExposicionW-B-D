import 'dart:async';
import 'dart:convert';
import 'package:conectalab/screens/users_screen.dart';
import 'package:conectalab/services/connectivity_service.dart';
import 'package:conectalab/services/users_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'connectivity_fakes.dart';

String responseBody() => jsonEncode({
  'users': [
    {
      'id': 1,
      'firstName': 'Ana',
      'lastName': 'Prueba',
      'email': 'ana@example.test',
      'address': {'city': 'Bogotá'},
      'company': {'name': 'Laboratorio'},
    },
  ],
  'total': 208,
});

void main() {
  test(
    'Carga datos remotos y conserva datos anteriores si falla la actualización',
    () async {
      var fail = false;
      final service = UsersService(
        client: MockClient((request) async {
          expect(request.url.host, 'dummyjson.com');
          expect(request.url.path, '/users');
          expect(
            request.url.queryParameters['select'],
            isNot(contains('password')),
          );
          if (fail) throw http.ClientException('Sin red');
          return http.Response.bytes(utf8.encode(responseBody()), 200);
        }),
      );
      await service.load();
      expect(service.status, UsersStatus.loaded);
      expect(service.users.single.name, 'Ana Prueba');
      expect(service.total, 208);
      expect(service.httpCode, 200);
      expect(service.loadedAt, isNotNull);
      fail = true;
      await service.load();
      expect(service.status, UsersStatus.failed);
      expect(service.httpCode, isNull);
      expect(service.users.length, 1);
      expect(service.error, contains('Wi-Fi'));
      service.dispose();
    },
  );
  test('Distingue HTTP de error y respuesta JSON inválida', () async {
    var code = 503;
    final service = UsersService(
      client: MockClient((_) async => http.Response('invalid', code)),
    );
    await service.load();
    expect(service.error, contains('HTTP 503'));
    code = 200;
    await service.load();
    expect(service.error, contains('formato esperado'));
    expect(service.httpCode, 200);
    service.dispose();
  });
  test(
    'Timeout, peticiones simultáneas y finalización después de dispose',
    () async {
      var calls = 0;
      final pending = Completer<http.Response>();
      final service = UsersService(
        timeout: const Duration(milliseconds: 10),
        client: MockClient((_) {
          calls++;
          return pending.future;
        }),
      );
      final load = service.load();
      await service.load();
      await load;
      expect(calls, 1);
      expect(service.status, UsersStatus.timeout);
      service.dispose();
      pending.complete(http.Response.bytes(utf8.encode(responseBody()), 200));
      await Future<void>.delayed(Duration.zero);
      expect(service.users, isEmpty);
    },
  );
  for (final size in [const Size(320, 640), const Size(1440, 1000)]) {
    testWidgets(
      'Tarjetas, fallo real simulado, reintento y permisos en $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var offline = true;
        var calls = 0;
        var permissionsOpened = false;
        final users = UsersService(
          client: MockClient((_) async {
            calls++;
            if (offline) throw http.ClientException('Sin red');
            return http.Response.bytes(utf8.encode(responseBody()), 200);
          }),
        );
        final source = FakeNetworkSource()..values = [ConnectivityResult.none];
        final connectivity = ConnectivityService(
          source: source,
          probe: FakeHttpsProbe(),
          isWeb: false,
        );
        connectivity.start();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UsersScreen(
                users: users,
                connectivity: connectivity,
                onPermissions: () => permissionsOpened = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> reveal(Finder finder) async {
          for (
            var i = 0;
            i < 20 && finder.hitTestable().evaluate().isEmpty;
            i++
          ) {
            await tester.drag(find.byType(ListView), const Offset(0, -200));
            await tester.pumpAndSettle();
          }
          expect(finder.hitTestable(), findsOneWidget);
        }

        expect(
          find.textContaining('No se pudo conectar con DummyJSON'),
          findsOneWidget,
        );
        await reveal(find.text('Ver permisos de la app'));
        await tester.tap(find.text('Ver permisos de la app'));
        expect(permissionsOpened, isTrue);
        offline = false;
        await reveal(find.text('Actualizar usuarios'));
        await tester.tap(find.text('Actualizar usuarios'));
        await tester.pumpAndSettle();
        expect(calls, 2);
        await reveal(find.text('Ana Prueba'));
        expect(find.text('Bogotá'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        users.dispose();
        connectivity.dispose();
        await source.controller.close();
      },
    );
  }
}
