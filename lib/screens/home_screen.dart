import 'package:flutter/material.dart';
import '../widgets/connectivity_card.dart';
import '../widgets/technology_card.dart';
import '../services/connectivity_service.dart';
import 'network_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onBluetooth,
    required this.service,
  });
  final ConnectivityService service;
  final VoidCallback onBluetooth;
  void openLesson(BuildContext context, bool mobile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => NetworkScreen(service: service, mobile: mobile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'EXPLORA · COMPRENDE · CONECTA',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 2,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'ConectaLab',
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Laboratorio de redes móviles',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          const Text(
            'Descubre cómo se comunican los dispositivos móviles. Explora datos móviles, Wi-Fi y Bluetooth y comprende el papel de cada tecnología.',
            style: TextStyle(height: 1.6, fontSize: 16),
          ),
          const SizedBox(height: 32),
          ConnectivityCard(service: service),
          const SizedBox(height: 32),
          Text(
            'Tres tecnologías, un mundo conectado',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Selecciona una tecnología para conocerla.'),
          const SizedBox(height: 20),
          // Wrap deja crecer las tarjetas con el texto sin imponer alturas rígidas.
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 580
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: width,
                    child: TechnologyCard(
                      title: 'Datos móviles',
                      icon: Icons.signal_cellular_alt,
                      description:
                          'Conéctate a Internet mediante la red de tu operador, incluso mientras te desplazas.',
                      onTap: () => openLesson(context, true),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: TechnologyCard(
                      title: 'Wi-Fi',
                      icon: Icons.wifi,
                      description:
                          'Accede a una red local sin cables para comunicar dispositivos y compartir acceso a Internet.',
                      onTap: () => openLesson(context, false),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: TechnologyCard(
                      title: 'Bluetooth',
                      icon: Icons.bluetooth,
                      description:
                          'Comunica dispositivos cercanos, como audífonos, sensores y otros accesorios.',
                      onTap: onBluetooth,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          const Text(
            'FASE 04 · Chat local, imágenes y conectividad',
            style: TextStyle(color: Color(0xFF9CB4CA)),
          ),
        ],
      ),
    ),
  );
}
