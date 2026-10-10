import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import '../widgets/permission_controls.dart';

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key, required this.service});
  final BluetoothService service;
  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.service.activate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.service.activate();
    } else if (state != AppLifecycleState.inactive) {
      // Una ventana de permiso puede causar inactive; no cancela esa acción.
      widget.service.deactivate();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.service.deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            Icons.bluetooth,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'Descubrimiento Bluetooth BLE',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'Solo anuncios de dispositivos cercanos. Esta fase no empareja, conecta ni lee características privadas.',
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 16),
            const Text(
              'Escaneo BLE no disponible en esta versión Web. Web Bluetooth depende del navegador, de HTTPS, de la elección explícita del usuario y de dispositivos compatibles. No equivale al escaneo general de Android/iOS.',
            ),
          ],
          const SizedBox(height: 20),
          ListenableBuilder(
            listenable: widget.service,
            builder: (context, _) {
              final service = widget.service;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          'Adaptador: ${adapterDescription(service.adapter)}',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Escaneo: ${service.scanning
                            ? 'En curso'
                            : service.busy
                            ? 'Preparando'
                            : 'Detenido'}',
                      ),
                      if (service.scanning || service.busy)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: LinearProgressIndicator(
                            semanticsLabel: 'Buscando dispositivos BLE',
                          ),
                        ),
                      if (service.blockedReason != null)
                        Text(service.blockedReason!),
                      if (service.error != null) Text(service.error!),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed:
                                service.permissions.busy ||
                                    !service.permissions.supported
                                ? null
                                : service.permissions.requestBluetooth,
                            icon: const Icon(Icons.shield_outlined),
                            label: const Text('Solicitar permisos'),
                          ),
                          FilledButton.icon(
                            onPressed: service.canScan ? service.start : null,
                            icon: const Icon(Icons.search),
                            label: const Text('Iniciar escaneo'),
                          ),
                          OutlinedButton.icon(
                            onPressed: service.scanning || service.busy
                                ? service.stop
                                : null,
                            icon: const Icon(Icons.stop),
                            label: const Text('Detener escaneo'),
                          ),
                          OutlinedButton.icon(
                            onPressed: service.busy || service.permissions.busy
                                ? null
                                : service.activate,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Comprobar Bluetooth'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Dispositivos encontrados: ${service.devices.length}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (service.devices.isEmpty)
                        Text(
                          service.attemptedScan
                              ? service.scanning
                                    ? 'Buscando anuncios BLE. Todavía no se han encontrado dispositivos.'
                                    : 'No se encontraron dispositivos. El resultado depende de periféricos BLE cercanos que estén anunciándose.'
                              : 'Todavía no se ha realizado un escaneo. Bluetooth activado no significa que haya dispositivos visibles.',
                        ),
                      for (final device in service.devices)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.name.isEmpty
                                    ? 'Dispositivo sin nombre anunciado'
                                    : device.name,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text('Identificador: ${device.id}'),
                              Text('RSSI recibido: ${device.rssi} dBm'),
                            ],
                          ),
                        ),
                      if (service.devices.isNotEmpty)
                        const Text(
                          'Son resultados del último escaneo, no conexiones actuales. El RSSI varía y no mide una distancia exacta. El identificador puede cambiar según el sistema.',
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          PermissionControls(service: widget.service.permissions),
          const SizedBox(height: 24),
          _lesson(
            context,
            'Del permiso al descubrimiento',
            '1. Pulsas Solicitar permisos.\n2. El sistema presenta la solicitud cuando corresponde.\n3. Concedes o deniegas.\n4. La app verifica el resultado.\n5. Con autorización y Bluetooth disponible, pulsas Iniciar escaneo.\n6. Los anuncios encontrados aparecen en la lista.',
          ),
          const SizedBox(height: 16),
          _lesson(
            context,
            'Bluetooth Classic y BLE',
            'Classic se usa en conexiones continuas tradicionales, como audio y accesorios. BLE está diseñado para intercambios breves y bajo consumo, habituales en sensores. Un equipo puede admitir ambos; este descubrimiento muestra únicamente BLE y no garantiza encontrar audífonos o dispositivos Classic.',
          ),
        ],
      ),
    ),
  );
  Widget _lesson(BuildContext context, String title, String body) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(height: 1.6)),
        ],
      ),
    ),
  );
}
