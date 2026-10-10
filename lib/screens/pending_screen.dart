import 'package:flutter/material.dart';

// Las secciones pendientes comparten diseño y explican su alcance.
class PendingScreen extends StatelessWidget {
  const PendingScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
  });
  final String title;
  final IconData icon;
  final String description;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                const Text('Disponible en una próxima fase'),
                const SizedBox(height: 16),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
