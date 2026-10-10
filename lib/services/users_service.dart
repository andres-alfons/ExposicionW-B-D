import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiUser {
  ApiUser(Map<String, dynamic> json)
    : id = json['id'] as int,
      name = '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim(),
      email = json['email'] as String? ?? '',
      image = json['image'] as String? ?? '',
      city = (json['address'] as Map?)?['city'] as String? ?? '',
      company = (json['company'] as Map?)?['name'] as String? ?? '';
  final int id;
  final String name, email, image, city, company;
}

enum UsersStatus { pending, loading, loaded, failed, timeout }

/// Esta petición consulta datos remotos; no sustituye el diagnóstico HTTPS.
class UsersService extends ChangeNotifier {
  UsersService({http.Client? client, this.timeout = const Duration(seconds: 8)})
    : _client = client ?? http.Client();
  final http.Client _client;
  final Duration timeout;
  List<ApiUser> users = const [];
  int total = 0;
  UsersStatus status = UsersStatus.pending;
  String? error;
  int? httpCode;
  DateTime? checkedAt, loadedAt;
  Duration? elapsed;
  bool _disposed = false;
  Completer<void>? _abort;
  bool get busy => status == UsersStatus.loading;

  Future<void> load() async {
    if (_disposed || busy) return;
    status = UsersStatus.loading;
    error = null;
    httpCode = null;
    elapsed = null;
    notifyListeners();
    final watch = Stopwatch()..start();
    final abort = Completer<void>();
    _abort = abort;
    try {
      final result = await _fetch(abort).timeout(timeout);
      if (_disposed) return;
      users = List.unmodifiable(result.$1);
      total = result.$2;
      loadedAt = DateTime.now();
      status = UsersStatus.loaded;
    } on TimeoutException {
      if (_disposed) return;
      status = UsersStatus.timeout;
      error =
          'La API no respondió en ${timeout.inSeconds} segundos. Revisa tu conexión y vuelve a intentar.';
    } on FormatException {
      if (_disposed) return;
      status = UsersStatus.failed;
      error =
          'El servidor respondió, pero los datos no tienen el formato esperado.';
    } catch (_) {
      if (_disposed) return;
      status = UsersStatus.failed;
      error = httpCode == null
          ? 'No se pudo conectar con DummyJSON. Revisa Wi-Fi o datos móviles. También puede fallar el servidor, DNS, TLS o CORS en Web.'
          : 'La API respondió HTTP $httpCode y no permitió cargar los usuarios. Hubo comunicación con el servidor.';
    } finally {
      watch.stop();
      if (!abort.isCompleted) abort.complete();
      _abort = null;
      if (!_disposed) {
        elapsed = watch.elapsed;
        checkedAt = DateTime.now();
        notifyListeners();
      }
    }
  }

  Future<(List<ApiUser>, int)> _fetch(Completer<void> abort) async {
    final uri = Uri.https('dummyjson.com', '/users', {
      'limit': '30',
      'select': 'id,firstName,lastName,email,image,address,company',
      '_conectalab_check': DateTime.now().microsecondsSinceEpoch.toString(),
    });
    final response = await _client.send(
      http.AbortableRequest('GET', uri, abortTrigger: abort.future),
    );
    if (_disposed || abort.isCompleted) throw StateError('Consulta cancelada');
    httpCode = response.statusCode;
    if (httpCode! < 200 || httpCode! >= 300) {
      await response.stream.listen((_) {}).cancel();
      throw StateError('Respuesta HTTP de error');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (_disposed || abort.isCompleted) {
        throw StateError('Consulta cancelada');
      }
      if (bytes.length + chunk.length > 1024 * 1024) {
        throw const FormatException('Respuesta demasiado grande');
      }
      bytes.add(chunk);
    }
    final json = jsonDecode(utf8.decode(bytes.takeBytes()));
    if (json is! Map<String, dynamic> ||
        json['users'] is! List ||
        json['total'] is! int) {
      throw const FormatException('Respuesta inválida');
    }
    try {
      final list = (json['users'] as List)
          .map((item) => ApiUser(item as Map<String, dynamic>))
          .toList();
      return (list, json['total'] as int);
    } catch (_) {
      throw const FormatException('Usuarios inválidos');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_abort?.isCompleted == false) _abort!.complete();
    _client.close();
    super.dispose();
  }
}
