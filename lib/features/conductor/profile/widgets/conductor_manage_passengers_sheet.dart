import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/widgets/lottie_widgets.dart';
import '../../../../core/widgets/profile_rows.dart';
import '../../../../data/repositories/bus_repository.dart';
import '../providers/conductor_profile_providers.dart';

class ConductorManagePassengersSheet extends ConsumerStatefulWidget {
  final String busId;
  const ConductorManagePassengersSheet({super.key, required this.busId});

  @override
  ConsumerState<ConductorManagePassengersSheet> createState() =>
      _ConductorManagePassengersSheetState();
}

class _ConductorManagePassengersSheetState
    extends ConsumerState<ConductorManagePassengersSheet> {
  String _search = '';

  Future<void> _removePassenger(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Passenger'),
        content: Text('Remove $name from this bus?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.t(context, 'Cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      // Removing means marking the passenger rejected.
      await ref.read(busRepositoryProvider).rejectPassenger(id);
      ref.invalidate(busPassengersProvider(widget.busId));
    } catch (e) {
      debugPrint('[MANAGE_PASS] remove error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed to remove passenger'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passengersAsync = ref.watch(busPassengersProvider(widget.busId));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                sheetHeader(context, S.t(context, 'Manage Passengers')),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: sheetInputDecoration(
                      S.t(context, 'Search by name or ID'), Icons.search),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: passengersAsync.when(
              loading: () => const Center(child: LottieLoading()),
              error: (e, _) => Center(
                  child: Text('Failed to load',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant))),
              data: (passengers) {
                final filtered = _search.isEmpty
                    ? passengers
                    : passengers
                        .where((p) =>
                            (p['name'] as String)
                                .toLowerCase()
                                .contains(_search.toLowerCase()) ||
                            (p['institute_id'] as String)
                                .toLowerCase()
                                .contains(_search.toLowerCase()))
                        .toList();
                if (filtered.isEmpty) {
                  return Center(
                      child: Text(S.t(context, 'No passengers'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  theme.colorScheme.onSurfaceVariant)));
                }
                return ListView.separated(
                  controller: controller,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    final name = p['name'] as String;
                    final regNum = p['institute_id'] as String;
                    final type = p['user_type'] as String;
                    final status = p['approval_status'] as String;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            theme.colorScheme.primaryContainer,
                        child: Text(
                          name[0].toUpperCase(),
                          style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '$regNum · ${type == 'faculty' ? S.t(context, 'Faculty') : S.t(context, 'Student')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (status != 'approved')
                            _statusBadge(status, theme),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(Icons.person_remove_outlined,
                                color: theme.colorScheme.error,
                                size: 20),
                            onPressed: () =>
                                _removePassenger(p['id'] as String, name),
                          ),
                        ],
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

  Widget _statusBadge(String status, ThemeData theme) {
    final color = status == 'pending'
        ? Colors.amber.shade700
        : theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}
