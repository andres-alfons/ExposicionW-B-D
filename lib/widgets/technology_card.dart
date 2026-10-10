import 'package:flutter/material.dart';

class TechnologyCard extends StatelessWidget {
  const TechnologyCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(description, style: const TextStyle(height: 1.6)),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Explorar',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
