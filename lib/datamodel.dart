

import 'package:uuid/uuid.dart';

class RecognizedIngredient {
  final String name;
  final double confidence;

  RecognizedIngredient({required this.name, required this.confidence});
}

class Recipe {
  final String id;
  final String name;
  final List<String> ingredients;
  final int cookTime;
  final String difficulty;
  final double rating;
  final List<RecipeStep> steps;
  final String? imageUrl;

  Recipe({
    required this.name,
    required this.ingredients,
    required this.cookTime,
    required this.difficulty,
    required this.rating,
    required this.steps,
    this.imageUrl,
  }) : id = const Uuid().v4();
}

class RecipeStep {
  final String title;
  final String description;
  final int? duration;
  final String? tip;

  RecipeStep({
    required this.title,
    required this.description,
    this.duration,
    this.tip,
  });
}

class ShoppingItem {
  String name;
  int quantity;
  String category;

  ShoppingItem({
    required this.name,
    required this.quantity,
    required this.category,
  });
}

class UserHealthProfile {
  int? age;
  double? weight;
  double? height;
  List<String> medicalConditions;
  String? dietRecommendation;

  UserHealthProfile({
  this.age,
  this.weight,
  this.height,
  this.medicalConditions = const [],
  this.dietRecommendation,


  });
}
