// Import section
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// You'll need to create this data model file or adjust according to your existing one
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

class HealthIntegrationScreen extends StatefulWidget {
  const HealthIntegrationScreen({Key? key}) : super(key: key);

  @override
  State<HealthIntegrationScreen> createState() => _HealthIntegrationScreenState();
}

class _HealthIntegrationScreenState extends State<HealthIntegrationScreen> {
  final HealthFactory _health = HealthFactory();
  List<HealthDataPoint> _healthData = [];
  bool _isLoading = false;
  bool _hasPermissions = false;
  UserHealthProfile _userProfile = UserHealthProfile();

  @override
  void initState() {
    super.initState();
    _loadSavedProfile();
    _checkPermissions();
  }

  Future<void> _loadSavedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final age = prefs.getInt('user_age');
      final weight = prefs.getDouble('user_weight');
      final height = prefs.getDouble('user_height');
      final conditions = prefs.getStringList('user_conditions') ?? [];

      if (mounted) {
        setState(() {
          _userProfile = UserHealthProfile(
            age: age,
            weight: weight,
            height: height,
            medicalConditions: conditions,
          );
        });
      }
    } catch (e) {
      print('Error loading saved profile: $e');
    }
  }

  Future<void> _saveProfile(UserHealthProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (profile.age != null) await prefs.setInt('user_age', profile.age!);
      if (profile.weight != null) await prefs.setDouble('user_weight', profile.weight!);
      if (profile.height != null) await prefs.setDouble('user_height', profile.height!);
      await prefs.setStringList('user_conditions', profile.medicalConditions);
    } catch (e) {
      print('Error saving profile: $e');
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final types = [
        HealthDataType.WEIGHT,
        HealthDataType.HEIGHT,
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
      ];

      final hasPermissions = await HealthFactory.hasPermissions(types);

      if (mounted) {
        setState(() => _hasPermissions = hasPermissions ?? false);
      }
    } catch (e) {
      print('Error checking permissions: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final types = [
        HealthDataType.WEIGHT,
        HealthDataType.HEIGHT,
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
      ];

      final success = await _health.requestAuthorization(types);

      if (mounted) {
        setState(() => _hasPermissions = success);

        if (!success) {
          _showErrorSnackBar('Health permissions denied. Manual entry only.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error requesting permissions: $e');
      }
    }
  }

  Future<void> _fetchHealthData() async {
    if (!_hasPermissions) {
      await _requestPermissions();
      if (!_hasPermissions) return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final lastWeek = now.subtract(const Duration(days: 7));

      final healthDataTypes = [
        HealthDataType.WEIGHT,
        HealthDataType.HEIGHT,
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
      ];

      final healthData = await _health.getHealthDataFromTypes(
          lastWeek,
          now,
          healthDataTypes
      );

      _updateProfileFromHealthData(healthData);

      if (mounted) {
        setState(() {
          _healthData = healthData;
        });
        _generateDietRecommendations();
        _showSuccessSnackBar('Health data synced successfully');
      }

    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error fetching health data: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateProfileFromHealthData(List<HealthDataPoint> healthData) {
    if (healthData.isEmpty) return;

    final weightData = healthData.where((d) => d.type == HealthDataType.WEIGHT).toList();
    final heightData = healthData.where((d) => d.type == HealthDataType.HEIGHT).toList();

    if (weightData.isNotEmpty) {
      weightData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
      final latestWeight = _parseHealthValue(weightData.first.value);
      if (latestWeight != null && latestWeight > 0) {
        _userProfile.weight = latestWeight;
      }
    }

    if (heightData.isNotEmpty) {
      heightData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
      final latestHeight = _parseHealthValue(heightData.first.value);
      if (latestHeight != null && latestHeight > 0) {
        _userProfile.height = latestHeight;
      }
    }
  }

  double? _parseHealthValue(dynamic value) {
    try {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);

      final stringValue = value.toString();
      final numericPattern = RegExp(r'[\d.]+');
      final match = numericPattern.firstMatch(stringValue);
      if (match != null) {
        return double.tryParse(match.group(0)!);
      }
      return null;
    } catch (e) {
      print('Error parsing health value: $e');
      return null;
    }
  }

  void _generateDietRecommendations() {
    List<String> recommendations = [];

    if (_userProfile.weight != null && _userProfile.height != null) {
      final heightInMeters = _userProfile.height! / 100;
      final bmi = _userProfile.weight! / (heightInMeters * heightInMeters);

      if (bmi < 18.5) {
        recommendations.add('Consider increasing caloric intake with nutrient-dense foods');
      } else if (bmi > 25) {
        recommendations.add('Focus on portion control and regular physical activity');
      } else {
        recommendations.add('Maintain current balanced diet approach');
      }
    }

    if (_userProfile.medicalConditions.contains('hypertension')) {
      recommendations.add('Limit sodium intake to less than 2,300mg daily');
      recommendations.add('Increase potassium-rich foods (bananas, leafy greens)');
    }

    if (_userProfile.medicalConditions.contains('diabetes')) {
      recommendations.add('Monitor carbohydrate intake and choose complex carbs');
      recommendations.add('Include fiber-rich foods to help manage blood sugar');
    }

    if (_userProfile.medicalConditions.contains('gluten intolerance')) {
      recommendations.add('Ensure gluten-free diet with varied nutrient sources');
    }

    if (_userProfile.age != null) {
      if (_userProfile.age! > 65) {
        recommendations.add('Focus on calcium and vitamin D for bone health');
        recommendations.add('Ensure adequate protein intake (1.2g/kg body weight)');
      }
    }

    if (recommendations.isEmpty) {
      recommendations.add('Maintain a balanced diet with variety from all food groups');
    }

    setState(() {
      _userProfile.dietRecommendation = recommendations.join('\n\n');
    });
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Integration'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHealthProfileSection(),
            const SizedBox(height: 20),
            _buildSyncSection(),
            if (_healthData.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildHealthDataSection(),
            ],
            if (_userProfile.dietRecommendation != null &&
                _userProfile.dietRecommendation!.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildRecommendationsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHealthProfileSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Health Profile',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            HealthProfileForm(
              profile: _userProfile,
              onSaved: (profile) async {
                setState(() => _userProfile = profile);
                await _saveProfile(profile);
                _generateDietRecommendations();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Health App Integration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              _hasPermissions
                  ? 'Connected to health app'
                  : 'Connect to sync data automatically',
              style: TextStyle(
                color: _hasPermissions ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _fetchHealthData,
                icon: _isLoading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Icon(_hasPermissions ? Icons.sync : Icons.health_and_safety),
                label: Text(_isLoading
                    ? 'Syncing...'
                    : _hasPermissions
                    ? 'Sync Health Data'
                    : 'Connect Health App'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthDataSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Health Data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_healthData.length} entries',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._healthData.take(5).map((point) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _formatHealthDataType(point.type),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    _formatHealthValue(point),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personalized Recommendations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                _userProfile.dietRecommendation!,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatHealthDataType(HealthDataType type) {
    switch (type) {
      case HealthDataType.WEIGHT:
        return 'Weight';
      case HealthDataType.HEIGHT:
        return 'Height';
      case HealthDataType.STEPS:
        return 'Steps';
      case HealthDataType.HEART_RATE:
        return 'Heart Rate';
      default:
        return type.toString().split('.').last;
    }
  }

  String _formatHealthValue(HealthDataPoint point) {
    final numericValue = _parseHealthValue(point.value);
    if (numericValue == null) return 'N/A';

    switch (point.type) {
      case HealthDataType.WEIGHT:
        return '${numericValue.toStringAsFixed(1)} kg';
      case HealthDataType.HEIGHT:
        return '${numericValue.toStringAsFixed(0)} cm';
      case HealthDataType.STEPS:
        return '${numericValue.toInt()} steps';
      case HealthDataType.HEART_RATE:
        return '${numericValue.toInt()} bpm';
      default:
        return numericValue.toString();
    }
  }
}

class HealthProfileForm extends StatefulWidget {
  final UserHealthProfile profile;
  final ValueChanged<UserHealthProfile> onSaved;

  const HealthProfileForm({
    Key? key,
    required this.profile,
    required this.onSaved
  }) : super(key: key);

  @override
  State<HealthProfileForm> createState() => _HealthProfileFormState();
}

class _HealthProfileFormState extends State<HealthProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  List<String> _conditions = [];

  final List<String> _availableConditions = [
    'hypertension',
    'diabetes',
    'gluten intolerance',
    'lactose intolerance',
    'heart disease',
    'high cholesterol',
  ];

  @override
  void initState() {
    super.initState();
    _ageController = TextEditingController(text: widget.profile.age?.toString() ?? '');
    _weightController = TextEditingController(text: widget.profile.weight?.toString() ?? '');
    _heightController = TextEditingController(text: widget.profile.height?.toString() ?? '');
    _conditions = List.from(widget.profile.medicalConditions);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ageController,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    border: OutlineInputBorder(),
                    suffixText: 'years',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final age = int.tryParse(value);
                      if (age == null || age < 1 || age > 120) {
                        return 'Enter valid age (1-120)';
                      }
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _weightController,
                  decoration: const InputDecoration(
                    labelText: 'Weight',
                    border: OutlineInputBorder(),
                    suffixText: 'kg',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final weight = double.tryParse(value);
                      if (weight == null || weight < 20 || weight > 300) {
                        return 'Enter valid weight (20-300 kg)';
                      }
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _heightController,
            decoration: const InputDecoration(
              labelText: 'Height',
              border: OutlineInputBorder(),
              suffixText: 'cm',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                final height = double.tryParse(value);
                if (height == null || height < 100 || height > 250) {
                  return 'Enter valid height (100-250 cm)';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Medical Conditions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _availableConditions.map((condition) => FilterChip(
              label: Text(_formatConditionName(condition)),
              selected: _conditions.contains(condition),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _conditions.add(condition);
                  } else {
                    _conditions.remove(condition);
                  }
                });
              },
              selectedColor: Colors.blue.shade200,
              checkmarkColor: Colors.blue.shade800,
            )).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Save Profile'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatConditionName(String condition) {
    return condition.split(' ').map((word) =>
    word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      final profile = UserHealthProfile(
        age: _ageController.text.isNotEmpty ? int.tryParse(_ageController.text) : null,
        weight: _weightController.text.isNotEmpty ? double.tryParse(_weightController.text) : null,
        height: _heightController.text.isNotEmpty ? double.tryParse(_heightController.text) : null,
        medicalConditions: _conditions,
      );
      widget.onSaved(profile);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }
}