import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/everlore_network_image.dart';

/// Reusable avatar/background generator used in world + character creation.
///
/// Prompt-FIRST flow: the editable visual prompt is always shown. It is filled
/// either by "Generate with AI" (which drafts it alongside everything else) or
/// by the creator typing their own — then "Generate image" renders from that
/// prompt. Regenerate re-rolls until they're happy. One portrait image serves as
/// both the listing avatar and the in-chat background. Empty [imageUrl] = none
/// yet; empty [prompt] = nothing to render until it's filled.
class ImageForge extends StatelessWidget {
  final String imageUrl;
  final String prompt;
  final bool busy;
  final String? error;
  final ValueChanged<String> onPromptChanged;
  final VoidCallback onGenerate;
  final Future<void> Function(Uint8List bytes, String filename) onUpload;

  /// A [Key] tied to the prompt's provenance — bump it (e.g. on autofill) to
  /// force the editable field to re-seed its [initialValue] from [prompt].
  final Key? promptFieldKey;

  const ImageForge({
    super.key,
    required this.imageUrl,
    required this.prompt,
    required this.busy,
    required this.error,
    required this.onPromptChanged,
    required this.onGenerate,
    required this.onUpload,
    this.promptFieldKey,
  });

  Future<void> _pickAndUpload() async {
    final selected = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (selected == null) return;
    await onUpload(await selected.readAsBytes(), selected.name);
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.isNotEmpty;
    final hasPrompt = prompt.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AVATAR & BACKGROUND',
          style: EverloreTheme.ui(
            size: 13,
            color: EverloreTheme.parchment,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose AI art or upload your own. One image appears on the card and '
          'as the chat background; uploads are preserved and optimized for fast '
          'loading. PNG, JPEG, WebP, and HEIC are supported.',
          style: EverloreTheme.ui(
            size: 12,
            color: EverloreTheme.ash,
            height: 1.4,
          ),
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
                        EverloreNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 720,
                          placeholder: const _Spinner(label: 'Loading…'),
                          errorWidget: const _Placeholder(
                            icon: Icons.broken_image_outlined,
                            label: 'Image failed to load',
                          ),
                          semanticLabel: 'World artwork',
                        ),
                        if (busy)
                          const _Spinner(
                            label: 'Conjuring a new take…',
                            dim: true,
                          ),
                      ],
                    )
                  : busy
                  ? const _Spinner(label: 'Conjuring your image…')
                  : const _Placeholder(
                      icon: Icons.auto_awesome_outlined,
                      label: 'No image yet',
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Editable prompt — always shown (prompt-first). Re-seeds when the
        // promptFieldKey changes (suggest / autofill).
        TextFormField(
          key: promptFieldKey,
          initialValue: prompt,
          onChanged: onPromptChanged,
          maxLines: 4,
          minLines: 2,
          maxLength: 1000,
          enabled: !busy,
          textCapitalization: TextCapitalization.sentences,
          style: EverloreTheme.ui(
            size: 13,
            color: EverloreTheme.parchment,
            height: 1.5,
          ),
          decoration: InputDecoration(
            labelText: 'Visual prompt',
            labelStyle: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
            hintText:
                'Describe the look, or use “Generate with AI” to draft it.',
            hintStyle: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
            counterText: '',
            filled: true,
            fillColor: EverloreTheme.void4.withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: EverloreTheme.goldDim.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: EverloreTheme.goldDim.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: EverloreTheme.gold,
                width: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        if (error != null) ...[
          Text(
            error!,
            style: EverloreTheme.ui(size: 12, color: EverloreTheme.crimson),
          ),
          const SizedBox(height: 8),
        ],

        // Either render from the prompt or choose original artwork. Both use
        // the same stored image URL and preview path.
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: (busy || !hasPrompt) ? null : onGenerate,
              icon: Icon(
                hasImage ? Icons.refresh_rounded : Icons.auto_awesome,
                size: 18,
              ),
              label: Text(hasImage ? 'Regenerate' : 'Generate image'),
              style: OutlinedButton.styleFrom(
                foregroundColor: EverloreTheme.gold,
                disabledForegroundColor: EverloreTheme.ash,
                side: BorderSide(
                  color: EverloreTheme.gold.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : _pickAndUpload,
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: Text(hasImage ? 'Replace with upload' : 'Upload your own'),
              style: OutlinedButton.styleFrom(
                foregroundColor: EverloreTheme.parchment,
                disabledForegroundColor: EverloreTheme.ash,
                side: BorderSide(
                  color: EverloreTheme.parchment.withValues(alpha: 0.3),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
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
              strokeWidth: 2.2,
              color: EverloreTheme.gold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: EverloreTheme.ui(size: 12, color: EverloreTheme.parchment),
          ),
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
          Text(
            label,
            style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
          ),
        ],
      ),
    );
  }
}
