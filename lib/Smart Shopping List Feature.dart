// Import section
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Common imports for all screens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'datamodel.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({Key? key}) : super(key: key);

  @override
  _ShoppingListScreenState createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final List<ShoppingItem> _shoppingList = [];
  final List<ShoppingItem> _pantryItems = [];
  final TextEditingController _itemController = TextEditingController();
  bool _showPantry = false;

  @override
  void initState() {
    super.initState();
    _loadShoppingList();
    _loadPantryItems();
  }

  Future<void> _loadShoppingList() async {
    // In a real app, this would load from shared preferences or a database
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _shoppingList.addAll([
        ShoppingItem(name: 'Apples', quantity: 5, category: 'Fruits'),
        ShoppingItem(name: 'Chicken Breast', quantity: 2, category: 'Meat'),
        ShoppingItem(name: 'Rice', quantity: 1, category: 'Grains'),
      ]);
    });
  }

  Future<void> _loadPantryItems() async {
    // In a real app, this would load from shared preferences or a database
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _pantryItems.addAll([
        ShoppingItem(name: 'Pasta', quantity: 2, category: 'Grains'),
        ShoppingItem(name: 'Tomato Sauce', quantity: 3, category: 'Canned Goods'),
        ShoppingItem(name: 'Olive Oil', quantity: 1, category: 'Oils'),
      ]);
    });
  }

  void _addItem() {
    if (_itemController.text.trim().isEmpty) return;

    setState(() {
      if (_showPantry) {
        _pantryItems.add(ShoppingItem(
          name: _itemController.text.trim(),
          quantity: 1,
          category: 'Other',
        ));
      } else {
        _shoppingList.add(ShoppingItem(
          name: _itemController.text.trim(),
          quantity: 1,
          category: 'Other',
        ));
      }
      _itemController.clear();
    });
  }

  void _generateShoppingListFromRecipe(Recipe recipe) {
    setState(() {
      for (var ingredient in recipe.ingredients) {
        if (!_pantryItems.any((item) => item.name.toLowerCase().contains(ingredient.toLowerCase()))) {
          _shoppingList.add(ShoppingItem(
            name: ingredient,
            quantity: 1,
            category: _getCategoryForIngredient(ingredient),
          ));
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ingredients from ${recipe.name} to shopping list')),
    );
  }

  String _getCategoryForIngredient(String ingredient) {
    // Simple categorization - would be more sophisticated in a real app
    final lowerIngredient = ingredient.toLowerCase();
    if (lowerIngredient.contains('apple') || lowerIngredient.contains('banana')) return 'Fruits';
    if (lowerIngredient.contains('chicken') || lowerIngredient.contains('beef')) return 'Meat';
    if (lowerIngredient.contains('rice') || lowerIngredient.contains('pasta')) return 'Grains';
    return 'Other';
  }

  Future<void> _orderGroceries() async {
    // This would integrate with a grocery delivery service API
    const url = 'https://www.instacart.com/';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch grocery service')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shopping List')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemController,
                    decoration: const InputDecoration(
                      labelText: 'Add item',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addItem(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addItem,
                ),
              ],
            ),
          ),
          SegmentedButton(
            segments: const [
              ButtonSegment(value: false, label: Text('Shopping List')),
              ButtonSegment(value: true, label: Text('My Pantry')),
            ],
            selected: {_showPantry},
            onSelectionChanged: (newSelection) {
              setState(() => _showPantry = newSelection.first);
            },
          ),
          Expanded(
            child: _showPantry
                ? _buildPantryList()
                : _buildShoppingList(),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: _orderGroceries,
              icon: const Icon(Icons.shopping_cart),
              label: const Text('Order Groceries Online'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingList() {
    if (_shoppingList.isEmpty) {
      return const Center(child: Text('Your shopping list is empty'));
    }

    return ListView.builder(
      itemCount: _shoppingList.length,
      itemBuilder: (context, index) {
        final item = _shoppingList[index];
        return Dismissible(
          key: Key(item.name),
          background: Container(color: Colors.red),
          onDismissed: (direction) {
            setState(() => _shoppingList.removeAt(index));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Removed ${item.name}'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () {
                    setState(() => _shoppingList.insert(index, item));
                  },
                ),
              ),
            );
          },
          child: ListTile(
            title: Text(item.name),
            subtitle: Text('${item.quantity} ${item.quantity == 1 ? 'unit' : 'units'} • ${item.category}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    setState(() {
                      if (item.quantity > 1) {
                        item.quantity--;
                      } else {
                        _shoppingList.removeAt(index);
                      }
                    });
                  },
                ),
                Text(item.quantity.toString()),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    setState(() => item.quantity++);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPantryList() {
    if (_pantryItems.isEmpty) {
      return const Center(child: Text('Your pantry is empty'));
    }

    return ListView.builder(
      itemCount: _pantryItems.length,
      itemBuilder: (context, index) {
        final item = _pantryItems[index];
        return ListTile(
          title: Text(item.name),
          subtitle: Text('${item.quantity} ${item.quantity == 1 ? 'unit' : 'units'} • ${item.category}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () {
                  setState(() {
                    if (item.quantity > 1) {
                      item.quantity--;
                    } else {
                      _pantryItems.removeAt(index);
                    }
                  });
                },
              ),
              Text(item.quantity.toString()),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  setState(() => item.quantity++);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}