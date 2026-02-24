import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/trackables/add_target_screen.dart';

class TargetsScreen extends ConsumerWidget {
  final Trackable trackable;

  const TargetsScreen({super.key, required this.trackable});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetsAsync = ref.watch(targetsProvider(trackable.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Targets for ${trackable.name}'),
      ),
      body: targetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (targets) {
          if (targets.isEmpty) {
            return const Center(
              child: Text('No targets yet. Add one!'),
            );
          }
          return ListView.builder(
            itemCount: targets.length,
            itemBuilder: (context, index) {
              final target = targets[index];
              return ListTile(
                title: Text(target.name),
                subtitle: Text('Below ${target.amount} ${trackable.unit} by ${target.time}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement edit target screen
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddTargetScreen(trackable: trackable),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
