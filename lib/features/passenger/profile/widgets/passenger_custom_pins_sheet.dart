import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/lottie_widgets.dart';
import '../../../../data/repositories/passenger_repository.dart';
import '../providers/passenger_profile_providers.dart';
import 'pin_location_picker.dart';

class PassengerCustomPinsSheet extends ConsumerWidget {
  final String busId;
  const PassengerCustomPinsSheet({super.key, required this.busId});

  Future<void> _addPin(BuildContext context, WidgetRef ref) async {
    // 1. Pick the location on a map.
    final position = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => PinLocationPicker(busId: busId)),
    );
    if (position == null || !context.mounted) return;

    // 2. Collect the label and notification threshold.
    final labelCtrl = TextEditingController();
    int threshold = 5;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Add Custom Pin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Label',
                  hintText: 'e.g. Near my colony gate',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: threshold,
                decoration: InputDecoration(
                  labelText: 'Notify me before',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: [2, 5, 10, 15]
                    .map(
                      (m) =>
                          DropdownMenuItem(value: m, child: Text('$m minutes')),
                    )
                    .toList(),
                onChanged: (v) => setSt(() => threshold = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.t(context, 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add Pin'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || labelCtrl.text.trim().isEmpty) return;

    // 3. Persist and refresh the list.
    try {
      await ref
          .read(passengerRepositoryProvider)
          .addCustomPin(
            busId: busId,
            label: labelCtrl.text.trim(),
            latitude: position.latitude,
            longitude: position.longitude,
            notifyMinutesBefore: threshold,
          );
      ref.invalidate(customPinsProvider(busId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e, fallback: 'Failed to add pin.')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String id,
    String label,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Pin'),
        content: Text('Remove "$label"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.t(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(S.t(context, 'Remove')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(passengerRepositoryProvider).deleteCustomPin(id);
    ref.invalidate(customPinsProvider(busId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pinsAsync = ref.watch(customPinsProvider(busId));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Text(
                  S.t(context, 'Custom Stop Pins'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _addPin(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Pin'),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: pinsAsync.when(
              loading: () => const Center(child: LottieLoading()),
              error: (e, _) => Center(
                child: Text(
                  'Failed to load pins',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              data: (pins) {
                if (pins.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_off_outlined,
                          size: 48,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No custom pins yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap "Add Pin" above, or long-press on the map',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  controller: controller,
                  itemCount: pins.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (_, i) {
                    final pin = pins[i];
                    final label = pin['label'] as String;
                    final mins = pin['notify_minutes_before'] as int;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(
                          0xFFE65100,
                        ).withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFFE65100),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Notify $mins min before arrival',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                          size: 20,
                        ),
                        onPressed: () =>
                            _delete(context, ref, pin['id'] as String, label),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
