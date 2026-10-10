import 'package:flutter/material.dart';
import '../services/permission_service.dart';
import '../widgets/permission_controls.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, required this.service});
  final PermissionService service;
  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  @override
  void initState() {
    super.initState();
    widget.service.refresh();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            Icons.shield_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'Centro de permisos',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'Cada solicitud empieza con una acción tuya. Puedes denegarla y seguir usando los diagnósticos de red.',
          ),
          const SizedBox(height: 16),
          PermissionControls(service: widget.service),
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Imágenes: el selector del sistema da acceso al archivo elegido sin pedir acceso general a la galería. iOS permite consultar y solicitar cámara aquí o al tomar una foto en Chat. Android usa la app de cámara del sistema sin añadir permiso CAMERA. En Web y escritorio la captura está oculta. Ubicación solo se solicita en Android 6–11 para descubrir BLE; no se consulta tu posición. Internet y estado de red no presentan una ventana de solicitud.',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
