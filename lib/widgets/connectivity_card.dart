import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

class ConnectivityCard extends StatelessWidget {
  const ConnectivityCard({super.key, required this.service});
  final ConnectivityService service;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, child) => Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.monitor_heart_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Diagnóstico de conectividad',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              child: Text(
                'Transporte reportado: ${service.transport.description}',
              ),
            ),
            const SizedBox(height: 8),
            Text('HTTPS: ${service.https.description}'),
            const SizedBox(height: 8),
            if (service.busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(
                  semanticsLabel: 'Consultando diagnóstico',
                ),
              ),
            if (service.https.elapsed != null)
              Text(
                'Tiempo hasta respuesta: ${service.https.elapsed!.inMilliseconds} ms',
              ),
            Text(
              'Última comprobación HTTPS: ${_formatTime(service.lastCheckedAt)}',
            ),
            if (service.transportError != null) Text(service.transportError!),
            if (service.https.status == HttpsStatus.failed ||
                service.https.status == HttpsStatus.timeout)
              const Text(
                'Esto no demuestra ausencia absoluta de Internet. Puede fallar el servidor, DNS, TLS, la red o CORS en Web.',
              ),
            const SizedBox(height: 12),
            const Text(
              'La prueba usa la ruta elegida por el sistema; no verifica cada transporte por separado ni mide su velocidad.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: service.busy ? null : service.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar diagnóstico'),
            ),
          ],
        ),
      ),
    ),
  );

  String _formatTime(DateTime? value) {
    if (value == null) return 'Sin completar';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}
