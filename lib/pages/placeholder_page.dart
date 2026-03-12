import 'package:flutter/material.dart';

import '../routes/app_routes.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.routePath,
    required this.description,
  });

  final String title;
  final String routePath;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    Text(description, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 16),
                    Text(
                      '路由路径: $routePath',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton(
                          onPressed: () {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              AppRoutes.home,
                              (route) {
                                return false;
                              },
                            );
                          },
                          child: const Text('回到首页'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).maybePop();
                          },
                          child: const Text('返回'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
