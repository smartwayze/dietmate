// Import section
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';
// Common imports for all screens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'datamodel.dart';



class RecipeSuggestionsScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const RecipeSuggestionsScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _RecipeSuggestionsScreenState createState() => _RecipeSuggestionsScreenState();
}

class _RecipeSuggestionsScreenState extends State<RecipeSuggestionsScreen> {
  List<RecognizedIngredient> _recognizedIngredients = [];
  List<Recipe> _suggestedRecipes = [];
  bool _isLoading = false;
  CameraController? _cameraController;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _initCamera();
  }

  Future<void> _loadModel() async {
    await Tflite.loadModel(
      model: "assets/food_model.tflite",
      labels: "assets/food_labels.txt",
    );
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) return;

    _cameraController = CameraController(
      widget.cameras[0],
      ResolutionPreset.medium,
    );

    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _recognizeIngredients() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() => _isLoading = true);

    try {
      final image = await _cameraController!.takePicture();
      var recognitions = await Tflite.runModelOnImage(
        path: image.path,
        numResults: 5,
        threshold: 0.5,
        imageMean: 127.5,
        imageStd: 127.5,
      );

      if (recognitions != null) {
        setState(() {
          _recognizedIngredients = recognitions.map((recognition) {
            return RecognizedIngredient(
              name: recognition['label'],
              confidence: recognition['confidence'],
            );
          }).toList();
        });

        _getRecipeSuggestions();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recognizing ingredients: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getRecipeSuggestions() async {
    // This would typically call an API with the recognized ingredients
    // For demo, we'll use mock data
    setState(() {
      _suggestedRecipes = [
        Recipe(
          name: 'Vegetable Stir Fry',
          ingredients: ['Carrot', 'Broccoli', 'Bell Pepper'],
          cookTime: 20,
          difficulty: 'Easy',
          rating: 4.5, steps: [],
        ),
        Recipe(
          name: 'Fruit Salad',
          ingredients: ['Apple', 'Banana', 'Orange'],
          cookTime: 10,
          difficulty: 'Easy',
          rating: 4.2, steps: [],
        ),
      ];
    });
  }

  Future<void> _validateDish(Recipe recipe) async {
    // Similar to _recognizeIngredients but compares with expected dish features
    // This would be more complex in a real implementation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Dish validation would compare with ${recipe.name}')),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    Tflite.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recipe Suggestions')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: _cameraController != null && _cameraController!.value.isInitialized
                ? CameraPreview(_cameraController!)
                : const Center(child: CircularProgressIndicator()),
          ),
          ElevatedButton(
            onPressed: _recognizeIngredients,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Recognize Ingredients'),
          ),
          if (_recognizedIngredients.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Recognized Ingredients:', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              children: _recognizedIngredients.map((ingredient) =>
                  Chip(label: Text('${ingredient.name} (${(ingredient.confidence * 100).toStringAsFixed(1)}%)'))
              ).toList(),
            ),
          ],
          if (_suggestedRecipes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Suggested Recipes:', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: _suggestedRecipes.length,
                itemBuilder: (context, index) {
                  final recipe = _suggestedRecipes[index];
                  return RecipeCard(
                    recipe: recipe,
                    onValidate: () => _validateDish(recipe),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onValidate;

  const RecipeCard({Key? key, required this.recipe, required this.onValidate}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(recipe.name, style: Theme.of(context).textTheme.titleLarge),
            Text('Ingredients: ${recipe.ingredients.join(', ')}'),
            Text('Time: ${recipe.cookTime} min | Difficulty: ${recipe.difficulty}'),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber),
                Text(recipe.rating.toString()),
                const Spacer(),
                ElevatedButton(
                  onPressed: onValidate,
                  child: const Text('Validate Dish'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}