import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/connectivity_service.dart';
import '../widgets/connectivity_card.dart';
import '../widgets/network_comparison.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key, required this.service, required this.mobile});
  final ConnectivityService service;
  final bool mobile;
  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  static const _settings = MethodChannel('conectalab/network_settings');
  bool _settingsAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkSettings();
  }

  Future<void> _checkSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final available = await _settings.invokeMethod<bool>('canOpen');
      if (mounted) setState(() => _settingsAvailable = available == true);
    } on PlatformException {
      // Una plataforma sin manejador mantiene las instrucciones manuales.
    } on MissingPluginException {
      // También permite ejecutar las pruebas de widgets sin código nativo.
    }
  }

  Future<void> _openSettings() async {
    bool opened = false;
    try {
      opened = await _settings.invokeMethod<bool>('open') == true;
    } on PlatformException {
      opened = false;
    } on MissingPluginException {
      opened = false;
    }
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No se pudieron abrir los ajustes. Ábrelos desde la configuración del dispositivo.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = widget.mobile;
    return Scaffold(
      appBar: AppBar(title: Text(mobile ? 'Datos móviles' : 'Wi-Fi')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(
                  mobile ? Icons.signal_cellular_alt : Icons.wifi,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  mobile
                      ? 'Internet a través de tu operador'
                      : 'Una red local sin cables',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                ListenableBuilder(
                  listenable: widget.service,
                  builder: (context, child) {
                    final reported = widget.service.transport.reports(
                      mobile
                          ? ConnectivityResult.mobile
                          : ConnectivityResult.wifi,
                    );
                    final status = reported == null
                        ? 'Desconocido o no disponible'
                        : reported
                        ? 'Reportado por el sistema'
                        : 'No reportado por el sistema';
                    return Text(
                      '${mobile ? 'Transporte celular' : 'Transporte Wi-Fi'}: $status',
                      style: Theme.of(context).textTheme.titleMedium,
                    );
                  },
                ),
                const SizedBox(height: 16),
                ConnectivityCard(service: widget.service),
                const SizedBox(height: 24),
                Text(
                  mobile
                      ? 'Los datos móviles conectan el teléfono con la red celular del operador mediante antenas. La disponibilidad depende de cobertura, configuración y servicio contratado.'
                      : 'El punto de acceso comunica dispositivos por radio dentro de una red local. El router enlaza redes y puede proporcionar salida a Internet a través de un proveedor. Un mismo equipo suele cumplir ambas funciones.',
                  style: const TextStyle(fontSize: 17, height: 1.6),
                ),
                const SizedBox(height: 24),
                Text(
                  'Qué observar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  mobile
                      ? 'Cobertura celular: disponibilidad de señal de un operador. Transporte reportado: lo que el sistema informa a la aplicación. Acceso a Internet: comunicación comprobada con un servidor. Son conceptos distintos.'
                      : 'Una red local permite comunicación cercana aunque el proveedor, el router o un portal de acceso impidan llegar a Internet. Conectarse al Wi-Fi no garantiza una salida a Internet.',
                  style: const TextStyle(height: 1.6),
                ),
                const SizedBox(height: 20),
                if (mobile) ...[
                  _educationCard(
                    context,
                    '3G',
                    'Tercera generación celular, orientada a voz y datos. Su disponibilidad depende del operador y de los retiros de redes en cada región.',
                  ),
                  _educationCard(
                    context,
                    '4G / LTE',
                    'Tecnología celular de banda ancha basada en redes de paquetes. El rendimiento depende de cobertura, congestión y dispositivo.',
                  ),
                  _educationCard(
                    context,
                    '5G',
                    'Amplía las capacidades de las redes celulares con distintas bandas y despliegues. No garantiza una velocidad o latencia concreta.',
                  ),
                  const Text(
                    'Estas tarjetas son educativas. La app no detecta la generación celular, señal exacta, saldo, plan contratado ni consumo mensual.',
                  ),
                ] else
                  const Text(
                    'Esta fase no consulta SSID, contraseña, IP local ni intensidad de señal.',
                  ),
                const SizedBox(height: 20),
                if (_settingsAvailable)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _openSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Abrir ajustes de red'),
                    ),
                  )
                else
                  const Text(
                    'Para cambiar la red, abre los ajustes del dispositivo. No hay acceso directo compatible configurado en esta plataforma.',
                  ),
                const SizedBox(height: 24),
                const NetworkComparison(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _educationCard(
    BuildContext context,
    String title,
    String description,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(height: 1.5)),
          ],
        ),
      ),
    ),
  );
}
