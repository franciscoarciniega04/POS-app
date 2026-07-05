import 'package:flutter/material.dart';

import '../../../data/local/app_database.dart';
import 'category_form_screen.dart';

enum _CategoryFilter { active, inactive, all }

enum _CategoryAction { edit, changeStatus }

class CategoriesScreen extends StatefulWidget {
  final AppDatabase database;

  const CategoriesScreen({super.key, required this.database});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _searchController = TextEditingController();

  _CategoryFilter _filter = _CategoryFilter.active;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Categorías de productos'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCategory,
        icon: const Icon(Icons.add),
        label: const Text('Nueva categoría'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Card(
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Buscar categoría',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: _searchController.clear,
                                    icon: const Icon(Icons.clear),
                                  ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Activas'),
                                selected: _filter == _CategoryFilter.active,
                                onSelected: (_) {
                                  setState(() {
                                    _filter = _CategoryFilter.active;
                                  });
                                },
                              ),
                              ChoiceChip(
                                label: const Text('Inactivas'),
                                selected: _filter == _CategoryFilter.inactive,
                                onSelected: (_) {
                                  setState(() {
                                    _filter = _CategoryFilter.inactive;
                                  });
                                },
                              ),
                              ChoiceChip(
                                label: const Text('Todas'),
                                selected: _filter == _CategoryFilter.all,
                                onSelected: (_) {
                                  setState(() {
                                    _filter = _CategoryFilter.all;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<ProductCategory>>(
                  stream: widget.database.watchProductCategories(
                    includeInactive: true,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'No se pudieron cargar las categorías: '
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final categories =
                        (snapshot.data ?? const <ProductCategory>[])
                            .where(_matchesFilter)
                            .where(_matchesSearch)
                            .toList();

                    if (categories.isEmpty) {
                      return const _EmptyCategories();
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: categories.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final category = categories[index];

                        return Card(
                          color: Colors.white,
                          surfaceTintColor: Colors.transparent,
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: category.isActive
                                    ? const Color(0xFFF5F3FF)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(
                                Icons.category_outlined,
                                color: category.isActive
                                    ? const Color(0xFF7C3AED)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            title: Text(
                              category.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              category.description?.trim().isNotEmpty == true
                                  ? category.description!
                                  : category.isActive
                                  ? 'Categoría activa'
                                  : 'Categoría inactiva',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: PopupMenuButton<_CategoryAction>(
                              onSelected: (action) {
                                switch (action) {
                                  case _CategoryAction.edit:
                                    _editCategory(category);
                                    break;
                                  case _CategoryAction.changeStatus:
                                    _changeStatus(category);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: _CategoryAction.edit,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('Editar'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: _CategoryAction.changeStatus,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      category.isActive
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                    title: Text(
                                      category.isActive
                                          ? 'Desactivar'
                                          : 'Reactivar',
                                    ),
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }

  bool _matchesFilter(ProductCategory category) {
    return switch (_filter) {
      _CategoryFilter.active => category.isActive,
      _CategoryFilter.inactive => !category.isActive,
      _CategoryFilter.all => true,
    };
  }

  bool _matchesSearch(ProductCategory category) {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return true;
    }

    return [
      category.name,
      category.description ?? '',
    ].join(' ').toLowerCase().contains(query);
  }

  void _refresh() {
    setState(() {});
  }

  Future<void> _createCategory() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryFormScreen(database: widget.database),
      ),
    );
  }

  Future<void> _editCategory(ProductCategory category) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CategoryFormScreen(database: widget.database, category: category),
      ),
    );
  }

  Future<void> _changeStatus(ProductCategory category) async {
    final newStatus = !category.isActive;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            newStatus ? 'Reactivar categoría' : 'Desactivar categoría',
          ),
          content: Text(
            newStatus
                ? 'La categoría volverá a estar disponible para los productos.'
                : 'Los productos conservarán la categoría, pero aparecerán como “Sin categoría” en el catálogo visual.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(newStatus ? 'Reactivar' : 'Desactivar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.database.setProductCategoryActive(
        categoryId: category.id,
        isActive: newStatus,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar el estado: $error')),
      );
    }
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.category_outlined,
              size: 66,
              color: Color(0xFF64748B),
            ),
            const SizedBox(height: 15),
            Text(
              'No hay categorías para mostrar.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
