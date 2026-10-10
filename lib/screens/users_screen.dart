import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../services/users_service.dart';
import '../widgets/connectivity_card.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({
    super.key,
    required this.users,
    required this.connectivity,
    required this.onPermissions,
  });
  final UsersService users;
  final ConnectivityService connectivity;
  final VoidCallback onPermissions;
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  @override
  void initState() {
    super.initState();
    // Solo al entrar por primera vez; reconstruir o cambiar pestañas no consulta.
    if (widget.users.status == UsersStatus.pending) widget.users.load();
  }

  String _time(DateTime? time) => time == null
      ? 'Sin comprobar'
      : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: ListenableBuilder(
        listenable: Listenable.merge([widget.users, widget.connectivity]),
        builder: (context, _) {
          final service = widget.users;
          final network = widget.connectivity;
          final stale =
              network.transport.noNetwork ||
              service.status == UsersStatus.failed ||
              service.status == UsersStatus.timeout;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Usuarios en línea',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Una operación que sí necesita Internet: consultar DummyJSON. Perfiles de ejemplo proporcionados por la API, no usuarios del chat.',
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            stale
                                ? Icons.cloud_off
                                : Icons.cloud_download_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Consulta remota · dummyjson.com',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Transporte: ${network.transport.description}'),
                      const SizedBox(height: 8),
                      Text(switch (service.status) {
                        UsersStatus.pending => 'API: pendiente de consultar',
                        UsersStatus.loading => 'API: cargando usuarios…',
                        UsersStatus.loaded =>
                          'API: respuesta recibida · HTTP ${service.httpCode}',
                        UsersStatus.failed ||
                        UsersStatus.timeout => 'API: no se pudo actualizar',
                      }),
                      Text(
                        'Último intento: ${_time(service.checkedAt)}${service.elapsed == null ? '' : ' · ${service.elapsed!.inMilliseconds} ms'}',
                      ),
                      if (network.transport.noNetwork)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'El sistema reporta ausencia de transporte. Activa Wi-Fi o datos móviles desde los ajustes del teléfono.',
                          ),
                        ),
                      if (service.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              service.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      if (stale || service.error != null) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Comprueba modo avión, Wi-Fi, datos móviles y que el sistema permita a ConectaLab usar la red. Internet no requiere una solicitud de permiso; cámara, ubicación y Bluetooth no habilitan esta consulta.',
                        ),
                        TextButton.icon(
                          onPressed: widget.onPermissions,
                          icon: const Icon(Icons.shield_outlined),
                          label: const Text('Ver permisos de la app'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: service.busy ? null : service.load,
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          service.busy ? 'Cargando…' : 'Actualizar usuarios',
                        ),
                      ),
                      if (service.busy)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(
                            semanticsLabel: 'Consultando API de usuarios',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('Diagnóstico de conexión HTTPS'),
                subtitle: Text(network.https.description),
                children: [ConnectivityCard(service: network)],
              ),
              const SizedBox(height: 20),
              if (service.users.isNotEmpty) ...[
                Text(
                  '${service.users.length} perfiles · ${service.total} disponibles en la API',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Última carga correcta: ${_time(service.loadedAt)}${stale ? ' · Datos anteriores guardados en esta sesión; no confirman conexión actual.' : ''}',
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 950
                        ? 3
                        : constraints.maxWidth >= 600
                        ? 2
                        : 1;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 16) / columns;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: service.users
                          .map(
                            (user) => SizedBox(
                              width: width,
                              child: _UserCard(user: user),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ] else if (!service.busy)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.people_outline, size: 56),
                      const SizedBox(height: 12),
                      Text(
                        service.status == UsersStatus.loaded
                            ? 'La API no devolvió usuarios.'
                            : 'Sin usuarios cargados. Revisa la conexión y pulsa actualizar.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              const Text(
                'A diferencia del chat local, esta consulta necesita llegar a un servidor. Una respuesta HTTP de error demuestra comunicación; un fallo no prueba por sí solo ausencia absoluta de Internet.',
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});
  final ApiUser user;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final fallback = Center(
      child: Text(
        user.name.isEmpty ? '?' : user.name.substring(0, 1),
        style: TextStyle(fontSize: 30, color: color),
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipOval(
                  child: Container(
                    width: 64,
                    height: 64,
                    color: const Color(0xFF12394B),
                    child: user.image.startsWith('https://')
                        ? Image.network(
                            user.image,
                            fit: BoxFit.cover,
                            semanticLabel: 'Avatar de ${user.name}',
                            errorBuilder: (_, _, _) => fallback,
                          )
                        : fallback,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name.isEmpty ? 'Sin nombre' : user.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Perfil #${user.id}',
                        style: TextStyle(color: color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detail(Icons.email_outlined, user.email),
            _detail(Icons.location_city, user.city),
            _detail(Icons.business_outlined, user.company),
          ],
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF83E5F7)),
        const SizedBox(width: 8),
        Expanded(child: Text(value.isEmpty ? 'No disponible' : value)),
      ],
    ),
  );
}
