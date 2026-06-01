import 'package:flutter/material.dart';
import '../../../../app/theme/nexus_theme.dart';

/// Reusable avatar/background generator used in world + character creation.
///
/// Flow: tap Generate → backend auto-suggests a visual prompt (if none yet) and
/// renders an image → the prompt becomes editable → Regenerate re-rolls until
/// the creator is happy. One portrait image serves as both listing avatar and
/// in-chat background. Empty [imageUrl] = nothing generated yet.
class ImageForge extends StatelessWidget {
  final String imageUrl;
  final String prompt;
  final bool busy;
  final String? error;
  final ValueChanged<String> onPromptChanged;
  final VoidCallback onGenerate;

  const ImageForge({
    super.key,
    required this.imageUrl,
    required this.prompt,
    required this.busy,
    required this.error,
    required this.onPromptChanged,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AVATAR & BACKGROUND',
            style: EverloreTheme.ui(
                size: 13,
                color: EverloreTheme.parchment,
                weight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          'A generated image — shown on the card and as the chat background. '
          'Style follows the voice you chose.',
          style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash, height: 1.4),
        ),
        const SizedBox(height: 12),

        // Preview (or placeholder) — portrait 3:4
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              color: EverloreTheme.void3,
              child: hasImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(imageUrl, fit: BoxFit.cover,
                            loadingBuilder: (c, child, p) =>
                                p == null ? child : const _Spinner(label: 'Loading…'),
                            errorBuilder: (c, e, s) =>
                                const _Placeholder(icon: Icons.broken_image_outlined, label: 'Image failed to load')),
                        if (busy) const _Spinner(label: 'Conjuring a new take…', dim: true),
                      ],
                    )
                  : busy
                      ? const _Spinner(label: 'Conjuring your image…')
                      : const _Placeholder(
                          icon: Icons.auto_awesome_outlined,
                          label: 'No image yet'),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Editable prompt (only once we have one to edit)
        if (prompt.isNotEmpty) ...[
          TextFormField(
            initialValue: prompt,
            onChanged: onPromptChanged,
            maxLines: 4,
            minLines: 2,
            maxLength: 1000,
            enabled: !busy,
            textCapitalization: TextCapitalization.sentences,
            style: EverloreTheme.ui(
                size: 13, color: EverloreTheme.parchment, height: 1.5),
            decoration: InputDecoration(
              labelText: 'Visual prompt (editable)',
              labelStyle: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
              counterText: '',
              filled: true,
              fillColor: EverloreTheme.void4.withValues(alpha: 0.5),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: EverloreTheme.goldDim.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: EverloreTheme.goldDim.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: EverloreTheme.gold, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        if (error != null) ...[
          Text(error!,
              style: EverloreTheme.ui(size: 12, color: EverloreTheme.crimson)),
          const SizedBox(height: 8),
        ],

        // Generate / Regenerate
        OutlinedButton.icon(
          onPressed: busy ? null : onGenerate,
          icon: Icon(hasImage ? Icons.refresh_rounded : Icons.auto_awesome,
              size: 18),
          label: Text(hasImage ? 'Regenerate' : 'Generate image'),
          style: OutlinedButton.styleFrom(
            foregroundColor: EverloreTheme.gold,
            side: BorderSide(color: EverloreTheme.gold.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  final String label;
  final bool dim;
  const _Spinner({required this.label, this.dim = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: dim ? Colors.black.withValues(alpha: 0.45) : null,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
                strokeWidth: 2.2, color: EverloreTheme.gold),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: EverloreTheme.ui(size: 12, color: EverloreTheme.parchment)),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Placeholder({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: EverloreTheme.ash),
          const SizedBox(height: 8),
          Text(label, style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash)),
        ],
      ),
    );
  }
}
