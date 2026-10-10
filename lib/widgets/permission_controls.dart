import 'package:flutter/material.dart';
import '../services/permission_service.dart';

/// Compartida por Bluetooth y el centro: las solicitudes usan el mismo servicio.
class PermissionControls extends StatelessWidget {
  const PermissionControls({super.key, required this.service});
  final PermissionService service;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (service.busy)
          const LinearProgressIndicator(semanticsLabel: 'Consultando permisos'),
        if (service.error != null) Text(service.error!),
        if (!service.supported && !service.busy)
          const Text(
            'La consulta de permisos BLE está disponible en Android e iOS. En esta plataforma no se solicitarán permisos nativos.',
          ),
        for (final permission in service.availablePermissions)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      permissionName(permission),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(permissionPurpose(permission)),
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        'Estado: ${accessDescription(service.states[permission] ?? AccessState.unknown)}',
                      ),
                    ),
                    if (service.requestResults[permission] != null)
                      Text(service.requestResults[permission]!),
                    if (service.states[permission] != AccessState.granted)
                      Text(
                        permission == AppPermission.camera
                            ? 'Sin esta autorización no se puede tomar una fotografía. El chat de texto y el selector de imágenes siguen disponibles.'
                            : 'Sin esta autorización no se habilita el descubrimiento BLE. Wi-Fi y datos móviles siguen disponibles.',
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              service.busy ||
                                  [
                                    AccessState.granted,
                                    AccessState.settings,
                                    AccessState.restricted,
                                  ].contains(service.states[permission])
                              ? null
                              : () => service.request(permission),
                          icon: const Icon(Icons.shield_outlined),
                          label: const Text('Solicitar permiso'),
                        ),
                        if (service.states[permission] ==
                                AccessState.settings ||
                            service.states[permission] ==
                                AccessState.restricted)
                          OutlinedButton.icon(
                            onPressed: service.busy
                                ? null
                                : service.openSettings,
                            icon: const Icon(Icons.settings_outlined),
                            label: const Text('Abrir ajustes de la app'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: service.busy ? null : service.refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Comprobar permisos'),
        ),
      ],
    ),
  );
}
