import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/widgets/profile_rows.dart';
import '../../../../data/repositories/bus_repository.dart';
import '../providers/conductor_profile_providers.dart';

class ConductorEditProfileSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> profile;
  const ConductorEditProfileSheet({super.key, required this.profile});

  @override
  ConsumerState<ConductorEditProfileSheet> createState() =>
      _ConductorEditProfileSheetState();
}

class _ConductorEditProfileSheetState
    extends ConsumerState<ConductorEditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.profile['display_name'] as String? ?? '');
    _phoneCtrl = TextEditingController(
        text: widget.profile['phone'] as String? ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(busRepositoryProvider).updateConductorProfile(
            displayName: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
          );
      ref.invalidate(conductorProfileProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('[PROFILE] save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed to save profile'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sheetHeader(context, S.t(context, 'Edit Profile')),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: sheetInputDecoration(
                S.t(context, 'Display Name'), Icons.person_outline),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration:
                sheetInputDecoration(S.t(context, 'Phone Number'), Icons.phone_outlined),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(S.t(context, 'Save Changes'),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
