// Import section
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
// Common imports for all screens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import 'datamodel.dart'; // for jsonEncode

class RecipeRatingScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeRatingScreen({Key? key, required this.recipe}) : super(key: key);

  @override
  _RecipeRatingScreenState createState() => _RecipeRatingScreenState();
}

class _RecipeRatingScreenState extends State<RecipeRatingScreen> {
  double _rating = 3;
  final TextEditingController _feedbackController = TextEditingController();
  final List<String> _tags = [];
  final List<String> _availableTags = [
    'Too Spicy', 'Not Spicy Enough', 'Too Sweet', 'Too Salty',
    'Easy to Make', 'Time Consuming', 'Healthy', 'Comfort Food',
    'Kid Friendly', 'Impressive', 'Weeknight Dinner', 'Meal Prep'
  ];

  Future<void> _submitRating() async {
    if (_feedbackController.text.trim().isEmpty && _rating == 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide some feedback or change the rating')),
      );
      return;
    }

    // In a real app, this would send to your backend
    final ratingData = {
      'recipeId': widget.recipe.id,
      'rating': _rating,
      'feedback': _feedbackController.text.trim(),
      'tags': _tags,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Save to shared preferences for demo
    final prefs = await SharedPreferences.getInstance();
    final ratings = prefs.getStringList('recipe_ratings') ?? [];
    ratings.add(jsonEncode(ratingData));
    await prefs.setStringList('recipe_ratings', ratings);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks for your feedback!')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Rate ${widget.recipe.name}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How would you rate this recipe?', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            Center(
              child: RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder: (context, _) => const Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                onRatingUpdate: (rating) {
                  setState(() => _rating = rating);
                },
              ),
            ),
            const SizedBox(height: 24),
            const Text('Tags (select all that apply):', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableTags.map((tag) {
                return FilterChip(
                  label: Text(tag),
                  selected: _tags.contains(tag),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _tags.add(tag);
                      } else {
                        _tags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text('Additional Feedback:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            TextField(
              controller: _feedbackController,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'What did you like or dislike about this recipe?',
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _submitRating,
                child: const Text('Submit Rating'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }
}