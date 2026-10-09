import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/indian_meal_result.dart';
import '../services/food_log_service.dart';
import '../services/roboflow_nutrition_service.dart';

class RoboflowMealAnalyzerWidget extends StatefulWidget {
  const RoboflowMealAnalyzerWidget({
    super.key,
    this.onMealLogged,
  });

  final VoidCallback? onMealLogged;

  @override
  State<RoboflowMealAnalyzerWidget> createState() => _RoboflowMealAnalyzerWidgetState();
}

class _RoboflowMealAnalyzerWidgetState extends State<RoboflowMealAnalyzerWidget> {
  XFile? _selectedXFile;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _isSaving = false;
  IndianMealResult? _nutritionResult;
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _textFoodController = TextEditingController();
  final TextEditingController _textGramController = TextEditingController();

  @override
  void dispose() {
    _textFoodController.dispose();
    _textGramController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1280,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedXFile = pickedFile;
          _imageBytes = bytes;
          _nutritionResult = null;
          _errorMessage = null;
        });
        await _analyzeMeal();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to select image: $e';
      });
    }
  }

  Future<void> _analyzeMeal() async {
    if (_selectedXFile == null || _imageBytes == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final filename = _selectedXFile!.name.isNotEmpty ? _selectedXFile!.name : 'meal.jpg';
    final result = await RoboflowNutritionService.instance.analyzeMealBytes(
      _imageBytes!,
      filename: filename,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.success) {
        _nutritionResult = result;
      } else {
        _errorMessage = result.error ?? 'Failed to parse meal nutrition data.';
      }
    });
  }

  Future<void> _analyzeMealFromText() async {
    final foodText = _textFoodController.text.trim();
    if (foodText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter what food items you ate!'),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final grams = double.tryParse(_textGramController.text.trim());

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedXFile = null;
      _imageBytes = null;
    });

    final result = await RoboflowNutritionService.instance.analyzeMealText(
      foodText,
      portionGrams: grams,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.success) {
        _nutritionResult = result;
      } else {
        _errorMessage = result.error ?? 'Failed to parse meal nutrition data.';
      }
    });
  }

  Future<void> _logMealToFoodLog() async {
    if (_nutritionResult == null || !_nutritionResult!.success) return;

    setState(() {
      _isSaving = true;
    });

    final totals = _nutritionResult!.totals;
    final itemNames = _nutritionResult!.items.map((i) => i.name).join(', ');
    final title = itemNames.isNotEmpty ? itemNames : 'Scanned Meal';
    final itemsSummaryStr = _nutritionResult!.items
        .map((i) => '• ${i.name} (${i.portionGrams.toInt()}g, ${i.caloriesKcal.toInt()} kcal)')
        .join('\n');
    final double totalPortion = _nutritionResult!.items.fold(
        0.0, (sum, i) => sum + i.portionGrams);

    await FoodLogService.instance.addEntry(
      name: title,
      calories: totals.totalCaloriesKcal > 0 ? totals.totalCaloriesKcal : null,
      proteinG: totals.totalProteinG > 0 ? totals.totalProteinG : null,
      carbsG: totals.totalCarbsG > 0 ? totals.totalCarbsG : null,
      fatG: totals.totalFatG > 0 ? totals.totalFatG : null,
      portionGrams: totalPortion > 0 ? totalPortion : null,
      itemsSummary: itemsSummaryStr.isNotEmpty ? itemsSummaryStr : null,
      photoPath: _selectedXFile?.path,
      imageBytes: _imageBytes,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _selectedXFile = null;
      _imageBytes = null;
      _nutritionResult = null;
      _errorMessage = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved "$title" (${totals.totalCaloriesKcal.toInt()} kcal) to History!'),
        backgroundColor: const Color(0xFFFF7A59),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    widget.onMealLogged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Photo Preview Box
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: _imageBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF0E6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lunch_dining_rounded,
                          size: 44,
                          color: Color(0xFFFF7A59),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Scan Meal Image',
                        style: TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          'Snap or upload a photo of your meal to calculate calories & macros',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF6F6A64),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // Action Buttons: Camera & Gallery
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFFFF7A59),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 20),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF111111),
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFFE5DFD7), width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Text-based Meal Entry Card (if user missed photo)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.edit_note_rounded, color: Color(0xFFFF7A59), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Or Add Meal in Text Format',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111111),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Forgot to take a photo? Type what you ate and how many grams to calculate nutrition.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6F6A64),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _textFoodController,
                  decoration: InputDecoration(
                    labelText: 'What did you eat?',
                    hintText: 'e.g. 2 Rotis, Paneer Curry & Dal',
                    prefixIcon: const Icon(Icons.fastfood_outlined, color: Color(0xFFFF7A59)),
                    filled: true,
                    fillColor: const Color(0xFFF9F7F4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE5DFD7)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE5DFD7)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFFF7A59), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textGramController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Weight in Grams',
                          hintText: 'e.g. 250',
                          suffixText: 'g',
                          prefixIcon: const Icon(Icons.scale_outlined, color: Color(0xFFFF7A59)),
                          filled: true,
                          fillColor: const Color(0xFFF9F7F4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE5DFD7)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE5DFD7)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFFF7A59), width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _analyzeMealFromText,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Calculate'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        backgroundColor: const Color(0xFF111111),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Loading State
          if (_isLoading) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: const [
                  CircularProgressIndicator(
                    color: Color(0xFFFF7A59),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Analyzing meal with AI...',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Detecting food items, portions, and nutrition values',
                    style: TextStyle(color: Color(0xFF6F6A64), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],

          // Error Display
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFD32F2F)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Nutrition Results Display
          if (_nutritionResult != null) ...[
            _buildNutritionSummaryCard(_nutritionResult!.totals),
            const SizedBox(height: 16),
            _buildItemsTable(_nutritionResult!.items),
            const SizedBox(height: 16),
            if (_nutritionResult!.disclaimer != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  'Note: ${_nutritionResult!.disclaimer}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8D8881),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _logMealToFoodLog,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 22),
              label: Text(_isSaving ? 'Saving...' : 'Log Meal to Daily Food Log'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A59),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                elevation: 4,
                shadowColor: const Color(0x40FF7A59),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],

          // Persistent Logged Meal History Section (Last 2 Days)
          const SizedBox(height: 32),
          Row(
            children: [
              const Icon(Icons.history_rounded, color: Color(0xFFFF7A59), size: 22),
              const SizedBox(width: 8),
              const Text(
                'Logged Meals History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111111),
                ),
              ),
              const Spacer(),
              StreamBuilder<List<FoodLogEntry>>(
                stream: FoodLogService.instance.entriesStream,
                initialData: FoodLogService.instance.currentEntries,
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A59).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count saved',
                      style: const TextStyle(
                        color: Color(0xFFFF7A59),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          StreamBuilder<List<FoodLogEntry>>(
            stream: FoodLogService.instance.entriesStream,
            initialData: FoodLogService.instance.currentEntries,
            builder: (context, snapshot) {
              final entries = snapshot.data ?? const [];
              if (entries.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'No logged meals yet. Snap or select a food photo above to log your first meal!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF6F6A64),
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return _buildSavedMealCard(entry);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSummaryCard(IndianMealTotals totals) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.analytics_rounded, color: Color(0xFFFF7A59), size: 22),
              SizedBox(width: 10),
              Text(
                'Meal Nutrition Summary',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMacroStatBox(
                  'Calories',
                  '${totals.totalCaloriesKcal.toInt()}',
                  'kcal',
                  const Color(0xFFE65100),
                  const Color(0xFFFFF4EC),
                  const Color(0xFFFFE0CC),
                  Icons.local_fire_department_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMacroStatBox(
                  'Protein',
                  totals.totalProteinG.toStringAsFixed(1),
                  'g',
                  const Color(0xFF1565C0),
                  const Color(0xFFF0F7FF),
                  const Color(0xFFD0E4FF),
                  Icons.fitness_center_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMacroStatBox(
                  'Carbs',
                  totals.totalCarbsG.toStringAsFixed(1),
                  'g',
                  const Color(0xFF2E7D32),
                  const Color(0xFFF2F9F2),
                  const Color(0xFFC8E6C9),
                  Icons.grain_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMacroStatBox(
                  'Fat',
                  totals.totalFatG.toStringAsFixed(1),
                  'g',
                  const Color(0xFFC2185B),
                  const Color(0xFFFFF0F3),
                  const Color(0xFFFFCDD2),
                  Icons.water_drop_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroStatBox(
    String label,
    String value,
    String unit,
    Color color,
    Color bg,
    Color borderColor,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6F6A64),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable(List<IndianMealItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.restaurant_rounded, color: Color(0xFFFF7A59), size: 22),
              SizedBox(width: 10),
              Text(
                'Identified Foods',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(
              color: Color(0xFFEEEAE4),
              height: 16,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0E6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.fastfood_rounded,
                        size: 20,
                        color: Color(0xFFFF7A59),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111111),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Portion: ${item.portionGrams.toInt()}g • ${item.category}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6F6A64),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0E6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${item.caloriesKcal.toInt()} kcal',
                        style: const TextStyle(
                          color: Color(0xFFE65100),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSavedMealCard(FoodLogEntry entry) {
    final dateStr = _formatTimestamp(entry.timestamp);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Saved Food Image Preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SizedBox(
              height: 200,
              child: _buildSavedPhotoWidget(entry),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Date/Time row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111111),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8D8881),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFD32F2F)),
                      onPressed: () => _confirmDeleteEntry(entry.id, entry.name),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Macro pill badges under image
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (entry.calories != null)
                        _buildMiniBadge(
                          '${entry.calories!.toInt()} kcal',
                          const Color(0xFFE65100),
                          const Color(0xFFFFF4EC),
                          Icons.local_fire_department_rounded,
                        ),
                      if (entry.proteinG != null) ...[
                        const SizedBox(width: 6),
                        _buildMiniBadge(
                          '${entry.proteinG!.toStringAsFixed(1)}g P',
                          const Color(0xFF1565C0),
                          const Color(0xFFF0F7FF),
                          Icons.fitness_center_rounded,
                        ),
                      ],
                      if (entry.carbsG != null) ...[
                        const SizedBox(width: 6),
                        _buildMiniBadge(
                          '${entry.carbsG!.toStringAsFixed(1)}g C',
                          const Color(0xFF2E7D32),
                          const Color(0xFFF2F9F2),
                          Icons.grain_rounded,
                        ),
                      ],
                      if (entry.fatG != null) ...[
                        const SizedBox(width: 6),
                        _buildMiniBadge(
                          '${entry.fatG!.toStringAsFixed(1)}g F',
                          const Color(0xFFC2185B),
                          const Color(0xFFFFF0F3),
                          Icons.water_drop_rounded,
                        ),
                      ],
                      if (entry.portionGrams != null) ...[
                        const SizedBox(width: 6),
                        _buildMiniBadge(
                          '${entry.portionGrams!.toInt()}g',
                          const Color(0xFF7B1FA2),
                          const Color(0xFFF3E5F5),
                          Icons.scale_rounded,
                        ),
                      ],
                    ],
                  ),
                ),

                // Items summary list under image
                if (entry.itemsSummary != null && entry.itemsSummary!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F6F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFECE6DD)),
                    ),
                    child: Text(
                      entry.itemsSummary!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4A4640),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedPhotoWidget(FoodLogEntry entry) {
    if (entry.photoBase64 != null && entry.photoBase64!.trim().isNotEmpty) {
      try {
        final bytes = base64Decode(entry.photoBase64!);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }

    if (entry.photoPath != null && entry.photoPath!.trim().isNotEmpty) {
      final file = File(entry.photoPath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }

    return Container(
      color: const Color(0xFFFFF0E6),
      child: const Center(
        child: Icon(Icons.fastfood_rounded, size: 48, color: Color(0xFFFF7A59)),
      ),
    );
  }

  Widget _buildMiniBadge(String text, Color color, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(entryDate).inDays;

    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $ampm';

    if (diffDays == 0) {
      return 'Today at $timeStr';
    } else if (diffDays == 1) {
      return 'Yesterday at $timeStr';
    } else {
      return '${dt.day}/${dt.month}/${dt.year} at $timeStr';
    }
  }

  void _confirmDeleteEntry(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Logged Meal?'),
        content: Text('Are you sure you want to remove "$name" from your logged meals history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              FoodLogService.instance.removeEntry(id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
