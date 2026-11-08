import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/app_data.dart';
import '../../services/auth_service.dart';
import '../../theme/app_animations.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/common_widgets.dart';

class LinkPersonScreen extends StatefulWidget {
  const LinkPersonScreen({super.key});

  @override
  State<LinkPersonScreen> createState() => _LinkPersonScreenState();
}

class _LinkPersonScreenState extends State<LinkPersonScreen> {
  final _code = TextEditingController();
  final _other = TextEditingController();
  final _focus = FocusNode();
  String? _otherError;
  String _relation = 'Son / Daughter';
  bool _busy = false;
  bool _done = false;
  String? _error;

  final _relations = const ['Son / Daughter', 'Spouse / Partner', 'Relative', 'Friend', 'Nurse / Carer', 'Other'];

  @override
  void dispose() {
    _code.dispose();
    _other.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _isOther => _relation == 'Other';

  Future<void> _link() async {
    // "Other" must say what the relationship actually is.
    if (_isOther && _other.text.trim().length < 2) {
      HapticFeedback.heavyImpact();
      setState(() => _otherError = 'Please tell us your relationship, e.g. Neighbour, Grandson');
      return;
    }
    final relation = _isOther ? _other.text.trim() : _relation;
    setState(() {
      _busy = true;
      _error = null;
      _otherError = null;
    });
    try {
      await AppData.instance.linkWithCode(_code.text, relation);
      if (!mounted) return;
      setState(() => _done = true);
      HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      eyebrow: 'One more step',
      title: 'Link a person',
      subtitle: 'Enter the code from their MedGuardian profile.',
      showBack: true,
      decorIcons: const [Icons.favorite_rounded, Icons.qr_code_2_rounded, Icons.shield_rounded, Icons.people_alt_rounded],
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _done
            ? Padding(
                key: const ValueKey('done'),
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: const [
                    DrawCheck(size: 96),
                    SizedBox(height: 18),
                    Text('Linked!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text("You'll now receive their alerts.", style: TextStyle(color: AppColors.textSecondary)),
                  ]),
                ),
              )
            : Column(
                key: const ValueKey('form'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: staggered([
                  const Text('Ask the person you care for to open MedGuardian → Profile and read out their 6-digit link code.', style: TextStyle(color: AppColors.textSecondary, height: 1.45)),
                  const SizedBox(height: 22),
                  GestureDetector(
                    onTap: () => _focus.requestFocus(),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_code, _focus]),
                      builder: (context, _) {
                        final text = _code.text;
                        return Stack(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(6, (i) {
                                final filled = i < text.length;
                                final active = i == text.length && _focus.hasFocus;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 48,
                                  height: 62,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: active ? AppColors.primary : (filled ? AppColors.primary.withOpacity(0.4) : AppColors.line), width: active ? 2 : 1.4),
                                    boxShadow: filled ? AppColors.softShadow(AppColors.primary) : null,
                                  ),
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 180),
                                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                                      child: Text(filled ? text[i] : '', key: ValueKey('$i${filled ? text[i] : ''}'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            // invisible field that actually receives the input
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0,
                                child: TextField(
                                  controller: _code,
                                  focusNode: _focus,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                  DropdownButtonFormField<String>(
                    value: _relation,
                    decoration: InputDecoration(labelText: 'Your relationship', prefixIcon: chipIcon(Icons.favorite_border_rounded, AppColors.coral)),
                    items: _relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setState(() {
                      _relation = v ?? _relation;
                      _otherError = null;
                    }),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _isOther
                        ? Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: TextField(
                              controller: _other,
                              autofocus: true,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (_) {
                                if (_otherError != null) setState(() => _otherError = null);
                              },
                              decoration: InputDecoration(
                                labelText: 'Your relationship *',
                                hintText: 'e.g. Neighbour, Grandson, Church friend',
                                prefixIcon: chipIcon(Icons.edit_rounded, AppColors.primary),
                                errorText: _otherError,
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const SizedBox(height: 22),
                  if (_error != null) ErrorBanner(_error!),
                  GradientButton(label: 'Link', icon: Icons.link_rounded, loading: _busy, onPressed: _code.text.length == 6 ? _link : null),
                ], startMs: 260),
              ),
      ),
    );
  }
}
