import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/nexus_theme.dart';

/// Neumorphic / skeuomorphic UI primitives for the "Crossing the Threshold"
/// auth pass. All reuse EverloreTheme tokens — no new colours.
///
///  • [NeuButton]    raised forged-metal pill that depresses on press
///  • [NeuField]     recessed input well with a gold focus glow
///  • [OtpField]     six forged slots that fill with gold digits
///  • [NeuSegmented] recessed track with a sliding raised pill
///  • [EngravedBanner] inset status plate (error / success)
///  • [ForgeMark]    static brand sigil for screen headers

/// A recessed-well decoration: dark-top gradient reads as carved into the
/// surface; a gold rim + glow lights up when [focused].
BoxDecoration neuRecessed({double radius = 14, bool focused = false}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [EverloreTheme.void0, EverloreTheme.void3],
    ),
    border: Border.all(
      color: focused
          ? EverloreTheme.gold
          : EverloreTheme.goldDim.withValues(alpha: 0.28),
      width: focused ? 1.5 : 1,
    ),
    boxShadow: focused
        ? [
            BoxShadow(
              color: EverloreTheme.gold.withValues(alpha: 0.18),
              blurRadius: 14,
            ),
          ]
        : null,
  );
}

/// Raised forged-metal CTA. [primary] = gold plate; otherwise a recessed ghost.
/// [accent] overrides the metal colour (e.g. violet for "Enter the Realm").
class NeuButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool primary;
  final IconData? icon;
  final Color? accent;
  const NeuButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.primary = true,
    this.icon,
    this.accent,
  });

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null && !widget.loading;
    final base = widget.accent ?? EverloreTheme.gold;
    final fg = widget.primary
        ? EverloreTheme.void0
        : (widget.accent ?? EverloreTheme.parchment);

    final content = widget.loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: widget.primary ? EverloreTheme.void0 : base,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 19, color: fg),
                const SizedBox(width: 10),
              ],
              Text(
                widget.label,
                style: TextStyle(fontFamily: EverloreTheme.uiFamily, 
                  color: fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          );

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: widget.primary
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: enabled
                        ? [
                            Color.lerp(base, EverloreTheme.goldGlow, 0.5)!,
                            base,
                            Color.lerp(base, Colors.black, 0.32)!,
                          ]
                        : [EverloreTheme.void4, EverloreTheme.void3],
                  )
                : null,
            color: widget.primary ? null : EverloreTheme.void2,
            border: widget.primary
                ? null
                : Border.all(
                    color: (widget.accent ?? EverloreTheme.goldDim)
                        .withValues(alpha: enabled ? 0.45 : 0.2),
                  ),
            boxShadow: widget.primary && enabled && !_pressed
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: base.withValues(alpha: 0.35),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: Opacity(opacity: enabled ? 1 : 0.6, child: content),
        ),
      ),
    );
  }
}

/// A recessed text-input well with a gold focus glow. Keeps its own FocusNode
/// for the glow unless you pass one.
class NeuField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;

  /// A custom leading widget (e.g. a dial-code selector) shown in place of
  /// [prefixIcon], followed by the same hairline divider.
  final Widget? prefix;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  /// Optional externally-owned focus node. Pair with [KeyboardAwareInputGroup]
  /// (see `keyboard_aware_scroll.dart`) when a button sits below the field.
  /// Falls back to an internal one.
  final FocusNode? focusNode;

  /// Extra space kept below the field when the framework scrolls it above the
  /// keyboard (e.g. room for a button directly under the field).
  final EdgeInsets scrollPadding;
  const NeuField({
    super.key,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.prefixIcon,
    this.prefix,
    this.onChanged,
    this.inputFormatters,
    this.focusNode,
    this.scrollPadding = const EdgeInsets.all(20),
  });

  @override
  State<NeuField> createState() => _NeuFieldState();
}

class _NeuFieldState extends State<NeuField> {
  FocusNode? _internalNode;
  FocusNode get _node => widget.focusNode ?? _internalNode!;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) _internalNode = FocusNode();
    _node.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    _internalNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: neuRecessed(focused: _node.hasFocus),
      child: Row(
        children: [
          if (widget.prefix != null) ...[
            widget.prefix!,
            const SizedBox(width: 10),
            _PrefixDivider(focused: _node.hasFocus),
            const SizedBox(width: 12),
          ] else if (widget.prefixIcon != null) ...[
            Icon(widget.prefixIcon,
                size: 18,
                color: _node.hasFocus
                    ? EverloreTheme.gold
                    : EverloreTheme.ash),
            const SizedBox(width: 12),
            // Hairline divider so the icon reads as a deliberate adornment,
            // not a second box nested in the well.
            _PrefixDivider(focused: _node.hasFocus),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _node,
              keyboardType: widget.keyboardType,
              scrollPadding: widget.scrollPadding,
              inputFormatters: widget.inputFormatters,
              onChanged: widget.onChanged,
              style: TextStyle(fontFamily: EverloreTheme.uiFamily, 
                  color: EverloreTheme.parchment, fontSize: 15),
              decoration: InputDecoration(
                isCollapsed: true,
                // Defeat the global inputDecorationTheme's filled void4 box —
                // the recessed well IS the surface; no nested fill/border.
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: TextStyle(fontFamily: EverloreTheme.uiFamily, 
                    color: EverloreTheme.ash.withValues(alpha: 0.6),
                    fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The hairline that separates a [NeuField] prefix from the input.
class _PrefixDivider extends StatelessWidget {
  final bool focused;
  const _PrefixDivider({required this.focused});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      color: (focused ? EverloreTheme.gold : EverloreTheme.goldDim)
          .withValues(alpha: 0.28),
    );
  }
}

// ──────────────── Dial-code selector ────────────────

/// A single country dialing code entry.
class DialCode {
  final String flag;
  final String name;
  final String code; // e.g. '+1'
  const DialCode(this.flag, this.name, this.code);
}

/// Comprehensive set of dialing codes covering the major sovereign countries
/// (and high-traffic territories like Hong Kong / Taiwan). Alphabetical by
/// name; the picker has search, so order stays predictable.
const List<DialCode> kDialCodes = [
  DialCode('🇦🇫', 'Afghanistan', '+93'),
  DialCode('🇦🇱', 'Albania', '+355'),
  DialCode('🇩🇿', 'Algeria', '+213'),
  DialCode('🇦🇩', 'Andorra', '+376'),
  DialCode('🇦🇴', 'Angola', '+244'),
  DialCode('🇦🇷', 'Argentina', '+54'),
  DialCode('🇦🇲', 'Armenia', '+374'),
  DialCode('🇦🇺', 'Australia', '+61'),
  DialCode('🇦🇹', 'Austria', '+43'),
  DialCode('🇦🇿', 'Azerbaijan', '+994'),
  DialCode('🇧🇸', 'Bahamas', '+1'),
  DialCode('🇧🇭', 'Bahrain', '+973'),
  DialCode('🇧🇩', 'Bangladesh', '+880'),
  DialCode('🇧🇧', 'Barbados', '+1'),
  DialCode('🇧🇾', 'Belarus', '+375'),
  DialCode('🇧🇪', 'Belgium', '+32'),
  DialCode('🇧🇿', 'Belize', '+501'),
  DialCode('🇧🇯', 'Benin', '+229'),
  DialCode('🇧🇹', 'Bhutan', '+975'),
  DialCode('🇧🇴', 'Bolivia', '+591'),
  DialCode('🇧🇦', 'Bosnia and Herzegovina', '+387'),
  DialCode('🇧🇼', 'Botswana', '+267'),
  DialCode('🇧🇷', 'Brazil', '+55'),
  DialCode('🇧🇳', 'Brunei', '+673'),
  DialCode('🇧🇬', 'Bulgaria', '+359'),
  DialCode('🇧🇫', 'Burkina Faso', '+226'),
  DialCode('🇧🇮', 'Burundi', '+257'),
  DialCode('🇰🇭', 'Cambodia', '+855'),
  DialCode('🇨🇲', 'Cameroon', '+237'),
  DialCode('🇨🇦', 'Canada', '+1'),
  DialCode('🇨🇻', 'Cape Verde', '+238'),
  DialCode('🇨🇫', 'Central African Republic', '+236'),
  DialCode('🇹🇩', 'Chad', '+235'),
  DialCode('🇨🇱', 'Chile', '+56'),
  DialCode('🇨🇳', 'China', '+86'),
  DialCode('🇨🇴', 'Colombia', '+57'),
  DialCode('🇰🇲', 'Comoros', '+269'),
  DialCode('🇨🇩', 'Congo (DRC)', '+243'),
  DialCode('🇨🇬', 'Congo (Republic)', '+242'),
  DialCode('🇨🇷', 'Costa Rica', '+506'),
  DialCode('🇨🇮', "Côte d'Ivoire", '+225'),
  DialCode('🇭🇷', 'Croatia', '+385'),
  DialCode('🇨🇺', 'Cuba', '+53'),
  DialCode('🇨🇾', 'Cyprus', '+357'),
  DialCode('🇨🇿', 'Czechia', '+420'),
  DialCode('🇩🇰', 'Denmark', '+45'),
  DialCode('🇩🇯', 'Djibouti', '+253'),
  DialCode('🇩🇴', 'Dominican Republic', '+1'),
  DialCode('🇪🇨', 'Ecuador', '+593'),
  DialCode('🇪🇬', 'Egypt', '+20'),
  DialCode('🇸🇻', 'El Salvador', '+503'),
  DialCode('🇪🇪', 'Estonia', '+372'),
  DialCode('🇸🇿', 'Eswatini', '+268'),
  DialCode('🇪🇹', 'Ethiopia', '+251'),
  DialCode('🇫🇯', 'Fiji', '+679'),
  DialCode('🇫🇮', 'Finland', '+358'),
  DialCode('🇫🇷', 'France', '+33'),
  DialCode('🇬🇦', 'Gabon', '+241'),
  DialCode('🇬🇲', 'Gambia', '+220'),
  DialCode('🇬🇪', 'Georgia', '+995'),
  DialCode('🇩🇪', 'Germany', '+49'),
  DialCode('🇬🇭', 'Ghana', '+233'),
  DialCode('🇬🇷', 'Greece', '+30'),
  DialCode('🇬🇹', 'Guatemala', '+502'),
  DialCode('🇬🇳', 'Guinea', '+224'),
  DialCode('🇬🇾', 'Guyana', '+592'),
  DialCode('🇭🇹', 'Haiti', '+509'),
  DialCode('🇭🇳', 'Honduras', '+504'),
  DialCode('🇭🇰', 'Hong Kong', '+852'),
  DialCode('🇭🇺', 'Hungary', '+36'),
  DialCode('🇮🇸', 'Iceland', '+354'),
  DialCode('🇮🇳', 'India', '+91'),
  DialCode('🇮🇩', 'Indonesia', '+62'),
  DialCode('🇮🇷', 'Iran', '+98'),
  DialCode('🇮🇶', 'Iraq', '+964'),
  DialCode('🇮🇪', 'Ireland', '+353'),
  DialCode('🇮🇱', 'Israel', '+972'),
  DialCode('🇮🇹', 'Italy', '+39'),
  DialCode('🇯🇲', 'Jamaica', '+1'),
  DialCode('🇯🇵', 'Japan', '+81'),
  DialCode('🇯🇴', 'Jordan', '+962'),
  DialCode('🇰🇿', 'Kazakhstan', '+7'),
  DialCode('🇰🇪', 'Kenya', '+254'),
  DialCode('🇽🇰', 'Kosovo', '+383'),
  DialCode('🇰🇼', 'Kuwait', '+965'),
  DialCode('🇰🇬', 'Kyrgyzstan', '+996'),
  DialCode('🇱🇦', 'Laos', '+856'),
  DialCode('🇱🇻', 'Latvia', '+371'),
  DialCode('🇱🇧', 'Lebanon', '+961'),
  DialCode('🇱🇸', 'Lesotho', '+266'),
  DialCode('🇱🇷', 'Liberia', '+231'),
  DialCode('🇱🇾', 'Libya', '+218'),
  DialCode('🇱🇮', 'Liechtenstein', '+423'),
  DialCode('🇱🇹', 'Lithuania', '+370'),
  DialCode('🇱🇺', 'Luxembourg', '+352'),
  DialCode('🇲🇴', 'Macau', '+853'),
  DialCode('🇲🇬', 'Madagascar', '+261'),
  DialCode('🇲🇼', 'Malawi', '+265'),
  DialCode('🇲🇾', 'Malaysia', '+60'),
  DialCode('🇲🇻', 'Maldives', '+960'),
  DialCode('🇲🇱', 'Mali', '+223'),
  DialCode('🇲🇹', 'Malta', '+356'),
  DialCode('🇲🇷', 'Mauritania', '+222'),
  DialCode('🇲🇺', 'Mauritius', '+230'),
  DialCode('🇲🇽', 'Mexico', '+52'),
  DialCode('🇲🇩', 'Moldova', '+373'),
  DialCode('🇲🇨', 'Monaco', '+377'),
  DialCode('🇲🇳', 'Mongolia', '+976'),
  DialCode('🇲🇪', 'Montenegro', '+382'),
  DialCode('🇲🇦', 'Morocco', '+212'),
  DialCode('🇲🇿', 'Mozambique', '+258'),
  DialCode('🇲🇲', 'Myanmar', '+95'),
  DialCode('🇳🇦', 'Namibia', '+264'),
  DialCode('🇳🇵', 'Nepal', '+977'),
  DialCode('🇳🇱', 'Netherlands', '+31'),
  DialCode('🇳🇿', 'New Zealand', '+64'),
  DialCode('🇳🇮', 'Nicaragua', '+505'),
  DialCode('🇳🇪', 'Niger', '+227'),
  DialCode('🇳🇬', 'Nigeria', '+234'),
  DialCode('🇲🇰', 'North Macedonia', '+389'),
  DialCode('🇳🇴', 'Norway', '+47'),
  DialCode('🇴🇲', 'Oman', '+968'),
  DialCode('🇵🇰', 'Pakistan', '+92'),
  DialCode('🇵🇸', 'Palestine', '+970'),
  DialCode('🇵🇦', 'Panama', '+507'),
  DialCode('🇵🇬', 'Papua New Guinea', '+675'),
  DialCode('🇵🇾', 'Paraguay', '+595'),
  DialCode('🇵🇪', 'Peru', '+51'),
  DialCode('🇵🇭', 'Philippines', '+63'),
  DialCode('🇵🇱', 'Poland', '+48'),
  DialCode('🇵🇹', 'Portugal', '+351'),
  DialCode('🇵🇷', 'Puerto Rico', '+1'),
  DialCode('🇶🇦', 'Qatar', '+974'),
  DialCode('🇷🇴', 'Romania', '+40'),
  DialCode('🇷🇺', 'Russia', '+7'),
  DialCode('🇷🇼', 'Rwanda', '+250'),
  DialCode('🇸🇦', 'Saudi Arabia', '+966'),
  DialCode('🇸🇳', 'Senegal', '+221'),
  DialCode('🇷🇸', 'Serbia', '+381'),
  DialCode('🇸🇬', 'Singapore', '+65'),
  DialCode('🇸🇰', 'Slovakia', '+421'),
  DialCode('🇸🇮', 'Slovenia', '+386'),
  DialCode('🇸🇴', 'Somalia', '+252'),
  DialCode('🇿🇦', 'South Africa', '+27'),
  DialCode('🇰🇷', 'South Korea', '+82'),
  DialCode('🇸🇸', 'South Sudan', '+211'),
  DialCode('🇪🇸', 'Spain', '+34'),
  DialCode('🇱🇰', 'Sri Lanka', '+94'),
  DialCode('🇸🇩', 'Sudan', '+249'),
  DialCode('🇸🇪', 'Sweden', '+46'),
  DialCode('🇨🇭', 'Switzerland', '+41'),
  DialCode('🇸🇾', 'Syria', '+963'),
  DialCode('🇹🇼', 'Taiwan', '+886'),
  DialCode('🇹🇯', 'Tajikistan', '+992'),
  DialCode('🇹🇿', 'Tanzania', '+255'),
  DialCode('🇹🇭', 'Thailand', '+66'),
  DialCode('🇹🇬', 'Togo', '+228'),
  DialCode('🇹🇹', 'Trinidad and Tobago', '+1'),
  DialCode('🇹🇳', 'Tunisia', '+216'),
  DialCode('🇹🇷', 'Türkiye', '+90'),
  DialCode('🇹🇲', 'Turkmenistan', '+993'),
  DialCode('🇺🇬', 'Uganda', '+256'),
  DialCode('🇺🇦', 'Ukraine', '+380'),
  DialCode('🇦🇪', 'United Arab Emirates', '+971'),
  DialCode('🇬🇧', 'United Kingdom', '+44'),
  DialCode('🇺🇸', 'United States', '+1'),
  DialCode('🇺🇾', 'Uruguay', '+598'),
  DialCode('🇺🇿', 'Uzbekistan', '+998'),
  DialCode('🇻🇪', 'Venezuela', '+58'),
  DialCode('🇻🇳', 'Vietnam', '+84'),
  DialCode('🇾🇪', 'Yemen', '+967'),
  DialCode('🇿🇲', 'Zambia', '+260'),
  DialCode('🇿🇼', 'Zimbabwe', '+263'),
];

/// The app's default dial code (United States). Used as the initial selection.
final DialCode kDefaultDialCode =
    kDialCodes.firstWhere((c) => c.name == 'United States');

/// Tappable dial-code chip for a [NeuField] prefix. Shows the flag + code and
/// opens [showDialCodePicker] on tap.
class DialCodeButton extends StatelessWidget {
  final DialCode value;
  final ValueChanged<DialCode> onChanged;
  const DialCodeButton({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final picked = await showDialCodePicker(context, selected: value);
        if (picked != null) onChanged(picked);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value.flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(
            value.code,
            style: TextStyle(
              fontFamily: EverloreTheme.uiFamily,
              color: EverloreTheme.parchment,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.expand_more,
              size: 18, color: EverloreTheme.ash),
        ],
      ),
    );
  }
}

/// A themed, searchable bottom sheet for choosing a [DialCode].
Future<DialCode?> showDialCodePicker(
  BuildContext context, {
  DialCode? selected,
}) {
  return showModalBottomSheet<DialCode>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _DialCodeSheet(selected: selected),
  );
}

class _DialCodeSheet extends StatefulWidget {
  final DialCode? selected;
  const _DialCodeSheet({this.selected});

  @override
  State<_DialCodeSheet> createState() => _DialCodeSheetState();
}

class _DialCodeSheetState extends State<_DialCodeSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? kDialCodes
        : kDialCodes
            .where((c) =>
                c.name.toLowerCase().contains(q) || c.code.contains(q))
            .toList();
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [EverloreTheme.void2, EverloreTheme.void1],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: EverloreTheme.goldDim, width: 1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Grab handle.
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: EverloreTheme.goldDim.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Choose your realm',
                style: GoogleFonts.cinzel(
                  color: EverloreTheme.parchment,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: NeuField(
                controller: _searchCtrl,
                hintText: 'Search country or code',
                prefixIcon: Icons.search,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: results.length,
                itemBuilder: (context, i) {
                  final c = results[i];
                  final isSel = widget.selected != null &&
                      c.code == widget.selected!.code &&
                      c.name == widget.selected!.name;
                  return ListTile(
                    leading:
                        Text(c.flag, style: const TextStyle(fontSize: 22)),
                    title: Text(
                      c.name,
                      style: TextStyle(
                        fontFamily: EverloreTheme.uiFamily,
                        color: EverloreTheme.parchment,
                        fontSize: 15,
                        fontWeight:
                            isSel ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    trailing: Text(
                      c.code,
                      style: TextStyle(
                        fontFamily: EverloreTheme.uiFamily,
                        color: isSel
                            ? EverloreTheme.gold
                            : EverloreTheme.ash,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Six forged slots that fill with gold digits as the code is typed. Bound to
/// [controller] so existing verify logic reads the value unchanged.
///
/// Supports SMS autofill (`AutofillHints.oneTimeCode` → the OS shows the code
/// from the notification above the keyboard) and clipboard paste (a transparent
/// interactive overlay sits on top, so long-press → Paste works). [onCompleted]
/// fires once the full code is present (typed, pasted, or autofilled).
class OtpField extends StatefulWidget {
  final TextEditingController controller;
  final int length;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onCompleted;
  final EdgeInsets scrollPadding;
  const OtpField({
    super.key,
    required this.controller,
    this.length = 6,
    this.autofocus = false,
    this.onChanged,
    this.onCompleted,
    this.scrollPadding = const EdgeInsets.all(20),
  });

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  late final FocusNode _node;
  bool _firedComplete = false;

  @override
  void initState() {
    super.initState();
    _node = FocusNode()..addListener(() => setState(() {}));
    widget.controller.addListener(_onText);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _node.requestFocus();
      });
    }
  }

  void _onText() {
    final v = widget.controller.text;
    widget.onChanged?.call(v);
    if (v.length == widget.length) {
      if (!_firedComplete) {
        _firedComplete = true;
        widget.onCompleted?.call();
      }
    } else {
      _firedComplete = false;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    return Stack(
      children: [
        // Forged slots (decorative, behind the capture field).
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(widget.length, (i) {
            final filled = i < text.length;
            final active = _node.hasFocus && i == text.length;
            return Container(
              width: 46,
              height: 56,
              alignment: Alignment.center,
              decoration: neuRecessed(focused: active),
              child: Text(
                filled ? text[i] : '',
                style: GoogleFonts.cinzel(
                  color: EverloreTheme.gold,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
        ),
        // Transparent interactive capture field on top — invisible text/cursor,
        // but taps focus it and long-press shows the Paste menu.
        Positioned.fill(
          child: TextField(
            controller: widget.controller,
            focusNode: _node,
            autofocus: widget.autofocus,
            scrollPadding: widget.scrollPadding,
            keyboardType: TextInputType.number,
            maxLength: widget.length,
            autofillHints: const [AutofillHints.oneTimeCode],
            enableInteractiveSelection: true,
            showCursor: false,
            cursorColor: Colors.transparent,
            style: const TextStyle(color: Colors.transparent, fontSize: 24),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              counterText: '',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

/// Recessed segmented control with a sliding raised pill. [options] length 2–3.
class NeuSegmented extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;
  const NeuSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final n = options.length;
    final align = n == 1 ? 0.0 : (selected / (n - 1)) * 2 - 1;
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: neuRecessed(radius: 14),
      child: Stack(
        children: [
          // Sliding raised pill.
          AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOutCubic,
            alignment: Alignment(align, 0),
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [EverloreTheme.void4, EverloreTheme.void3],
                  ),
                  border: Border.all(
                      color: EverloreTheme.gold.withValues(alpha: 0.45)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(n, (i) {
              final sel = i == selected;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      options[i],
                      style: TextStyle(fontFamily: EverloreTheme.uiFamily, 
                        color: sel ? EverloreTheme.gold : EverloreTheme.ash,
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Inset status plate. [error] tints crimson; otherwise verdant.
class EngravedBanner extends StatelessWidget {
  final String message;
  final bool error;
  const EngravedBanner({super.key, required this.message, this.error = false});

  @override
  Widget build(BuildContext context) {
    final tint = error ? EverloreTheme.crimson : EverloreTheme.verdant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            EverloreTheme.void0,
            tint.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(error ? Icons.error_outline : Icons.check_circle_outline,
              color: tint, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontFamily: EverloreTheme.uiFamily, color: tint, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Static forged-sigil brand mark for screen headers — the same engraved rune
/// as the splash, sized to [size], rendered on a neumorphic disc.
class ForgeMark extends StatelessWidget {
  final double size;
  const ForgeMark({super.key, this.size = 84});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.4),
          radius: 1.1,
          colors: [EverloreTheme.void3, EverloreTheme.void0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20,
            offset: const Offset(8, 10),
          ),
          const BoxShadow(
            color: Color(0x1AAFA8FF),
            blurRadius: 16,
            offset: Offset(-7, -9),
          ),
          BoxShadow(
            color: EverloreTheme.gold.withValues(alpha: 0.12),
            blurRadius: 34,
            spreadRadius: 2,
          ),
        ],
      ),
      child: CustomPaint(painter: _ForgeMarkPainter()),
    );
  }
}

class _ForgeMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // Forged gold rim.
    final rimRect = Rect.fromCircle(center: c, radius: r * 0.78);
    canvas.drawCircle(
      c,
      r * 0.78,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..shader = const SweepGradient(
          colors: [
            EverloreTheme.goldDim,
            EverloreTheme.goldGlow,
            EverloreTheme.gold,
            EverloreTheme.goldDim,
            EverloreTheme.goldGlow,
            EverloreTheme.goldDim,
          ],
          stops: [0.0, 0.2, 0.45, 0.7, 0.88, 1.0],
        ).createShader(rimRect),
    );

    // Engraved rune.
    final glyph = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = EverloreTheme.goldGlow.withValues(alpha: 0.92);
    final glyphShadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.black.withValues(alpha: 0.55);
    final g = r * 0.32;
    final path = Path()
      ..moveTo(c.dx, c.dy - g)
      ..lineTo(c.dx, c.dy + g)
      ..moveTo(c.dx, c.dy - g)
      ..lineTo(c.dx - g * 0.62, c.dy - g * 0.18)
      ..moveTo(c.dx, c.dy - g)
      ..lineTo(c.dx + g * 0.62, c.dy - g * 0.18)
      ..moveTo(c.dx, c.dy + g)
      ..lineTo(c.dx - g * 0.62, c.dy + g * 0.18)
      ..moveTo(c.dx, c.dy + g)
      ..lineTo(c.dx + g * 0.62, c.dy + g * 0.18);
    canvas.save();
    canvas.translate(0.6, 1.0);
    canvas.drawPath(path, glyphShadow);
    canvas.restore();
    canvas.drawPath(path, glyph);
    canvas.drawCircle(c, 2.6, Paint()..color = EverloreTheme.goldGlow);
  }

  @override
  bool shouldRepaint(_ForgeMarkPainter old) => false;
}
