import 'package:flutter/material.dart';
import '../../app/theme/nexus_theme.dart';

class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: EverloreTheme.crimson.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: EverloreTheme.crimson.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: EverloreTheme.crimson, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: EverloreTheme.crimson, fontSize: 13),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: EverloreTheme.crimson,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Retry',
                  style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
