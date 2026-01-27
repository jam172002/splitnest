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
  bool _isAdding = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _onAdd(GroupRepo repo) async {
    final text = _name.text.trim().toLowerCase();
    if (text.isEmpty) return;

    setState(() => _isAdding = true);
    try {
      await repo.addCategory(widget.groupId, text);
      _name.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final repo = context.read<GroupRepo>();

    return AppScaffold(
      title: 'Manage Categories',
      child: Column(
        children: [
          // --- Input Header Section ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow, //
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _onAdd(repo),
                    decoration: InputDecoration(
                      hintText: 'Add category (e.g. Rent)',
                      prefixIcon: const Icon(Icons.label_outline_rounded),
                      filled: true,
                      fillColor: colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _isAdding
                    ? const SizedBox(width: 48, height: 48, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 3)))
                    : FloatingActionButton.small(
                  onPressed: () => _onAdd(repo),
                  elevation: 0,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),

          // --- Categories List Section ---
          Expanded(
            child: StreamBuilder(
              stream: repo.watchCategoryDocs(widget.groupId),
              builder: (context, snap) {
                final items = (snap.data ?? const <Map<String, dynamic>>[]) as List<Map<String, dynamic>>;

                if (snap.connectionState == ConnectionState.waiting && items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.category_outlined, size: 64, color: colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        Text('No custom categories yet.', style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.outline)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final it = items[i];
                    final name = (it['name'] ?? '').toString();

                    return Card(
                      elevation: 0,
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: Icon(Icons.tag, size: 18, color: colorScheme.onPrimaryContainer),
                        ),
                        title: Text(
                          name,
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
                          onPressed: () => repo.deleteCategory(widget.groupId, it['id'].toString()),
                        ),
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