import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/group_repo.dart';
import '../../widgets/app_scaffold.dart';

class CategoriesScreen extends StatefulWidget {
  final String groupId;
  const CategoriesScreen({super.key, required this.groupId});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<GroupRepo>();

    return AppScaffold(
      title: 'Categories',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Add category (e.g. rent)'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  await repo.addCategory(widget.groupId, _name.text);
                  _name.clear();
                },
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder(
              stream: repo.watchCategoryDocs(widget.groupId),
              builder: (context, snap) {
                final items = (snap.data ?? const <Map<String, dynamic>>[]) as List<Map<String, dynamic>>;
                if (items.isEmpty) {
                  return const Center(child: Text('No categories yet.'));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final it = items[i];
                    return ListTile(
                      title: Text((it['name'] ?? '').toString()),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => repo.deleteCategory(widget.groupId, it['id'].toString()),
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
