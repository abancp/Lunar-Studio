import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:LunarStudio/src/core/db/app_db.dart';

class ExternalApiSettings extends StatefulWidget {
  const ExternalApiSettings({super.key});

  @override
  State<ExternalApiSettings> createState() => _ExternalApiSettingsState();
}

class _ExternalApiSettingsState extends State<ExternalApiSettings> {
  bool _enabled = false;
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelNameController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final db = await AppDB.instance;
      final List<Map<String, dynamic>> maps = await db.query('settings');
      final Map<String, String> settings = {
        for (var map in maps) map['key'] as String: map['value'] as String,
      };

      setState(() {
        _enabled = settings['external_api_enabled'] == 'true';
        _apiKeyController.text = settings['external_api_key'] ?? '';
        _modelNameController.text = settings['external_api_model'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(String key, String value) async {
    try {
      final db = await AppDB.instance;
      await db.insert('settings', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('Error saving setting $key: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'External API Configuration',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure settings for using an external Model provider.',
            style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          // Enable Switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable External API',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Toggle to switch between local and external models.',
                        style: textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _enabled,
                  onChanged: (value) {
                    setState(() => _enabled = value);
                    _saveSetting('external_api_enabled', value.toString());
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // API Key Input
          Text(
            'API Key',
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyController,
            decoration: InputDecoration(
              hintText: 'Paste your API key here',
              hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.7)),
              filled: true,
              fillColor: cs.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: cs.primary),
              ),
              prefixIcon: Icon(Icons.key, color: cs.onSurfaceVariant),
            ),
            onChanged: (value) => _saveSetting('external_api_key', value),
          ),
          const SizedBox(height: 16),

          // Model Name Input
          Text(
            'Model Name',
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _modelNameController,
            decoration: InputDecoration(
              hintText: 'Enter model name (e.g., gpt-4, claude-3)',
              hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.7)),
              filled: true,
              fillColor: cs.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: cs.primary),
              ),
              prefixIcon: Icon(Icons.smart_toy, color: cs.onSurfaceVariant),
            ),
            onChanged: (value) => _saveSetting('external_api_model', value),
          ),
        ],
      ),
    );
  }
}
