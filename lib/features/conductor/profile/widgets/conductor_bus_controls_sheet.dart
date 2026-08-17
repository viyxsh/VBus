import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/widgets/profile_rows.dart';
import '../../../../data/repositories/bus_repository.dart';
import '../providers/conductor_profile_providers.dart';

class ConductorBusControlsSheet extends ConsumerStatefulWidget {
  const ConductorBusControlsSheet({super.key});

  @override
  ConsumerState<ConductorBusControlsSheet> createState() =>
      _ConductorBusControlsSheetState();
}

class _ConductorBusControlsSheetState
    extends ConsumerState<ConductorBusControlsSheet> {
  int _rowsLeft = 0;
  int _rowsRight = 0;
  int _totalLeftRows = 0;
  int _totalRightRows = 0;
  late String _busId;
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromProvider());
  }

  Future<void> _loadFromProvider() async {
    final profile = await ref.read(conductorProfileProvider.future);
    if (!mounted) return;
    final bus = profile['buses'] as Map;
    _busId = profile['bus_id'] as String;
    final leftSeats = (bus['left_seats'] as num).toInt();
    final studentSeats = (bus['student_seats'] as num).toInt();
    final backCount = studentSeats >= 6 ? 6 : studentSeats;
    final rightCount = studentSeats - backCount;

    setState(() {
      _totalLeftRows = (leftSeats / 2).ceil();
      _totalRightRows = (rightCount / 3).ceil();
      _rowsLeft = (bus['faculty_reserved_rows_left'] as num).toInt();
      _rowsRight = (bus['faculty_reserved_rows_right'] as num).toInt();
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(busRepositoryProvider).updateFacultyRows(
            busId: _busId,
            reservedRowsLeft: _rowsLeft,
            reservedRowsRight: _rowsRight,
          );
      ref.invalidate(conductorProfileProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('[BUS_CTRL] Save FAILED: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed to save bus controls'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sheetHeader(context, S.t(context, 'Bus Controls')),
          const SizedBox(height: 8),
          Text(
            'Set how many rows from the top of each side are reserved for faculty (yellow seats).',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _rowStepper(theme, 'Left side reserved rows',
                'Faculty rows on left column', _rowsLeft, _totalLeftRows,
                (v) => setState(() => _rowsLeft = v)),
            const SizedBox(height: 16),
            _rowStepper(theme, 'Right side reserved rows',
                'Faculty rows on right column', _rowsRight, _totalRightRows,
                (v) => setState(() => _rowsRight = v)),
            const SizedBox(height: 28),
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
                  : Text(S.t(context, 'Save'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rowStepper(ThemeData theme, String label, String sub,
      int value, int max, ValueChanged<int> onChange) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Text(sub,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > 0 ? () => onChange(value - 1) : null,
        ),
        SizedBox(
          width: 36,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max ? () => onChange(value + 1) : null,
        ),
      ],
    );
  }
}
