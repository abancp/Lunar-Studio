import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';

class ModelDropdown extends StatefulWidget {
  final String selectedModel;
  final ValueChanged<String> onSelect;

  const ModelDropdown({
    super.key,
    required this.selectedModel,
    required this.onSelect,
  });

  @override
  State<ModelDropdown> createState() => _ModelDropdownState();
}

class _ModelDropdownState extends State<ModelDropdown> {
  OverlayEntry? _overlayEntry;
  bool isOpen = false;
  List<String> models = [];

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  Future<void> _loadModels() async {
    final dir = await getApplicationSupportDirectory();
    final modelDir = Directory("${dir.path}/models");

    if (!modelDir.existsSync()) {
      modelDir.createSync(recursive: true);
    }

    final files = modelDir
        .listSync()
        .whereType<File>()
        .where((file) => p.extension(file.path) == ".gguf")
        .map((file) => p.basename(file.path))
        .toList();

    setState(() {
      models = files;
    });
    models.add("Import Model");
  }

  void _toggleDropdown() {
    if (isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (_) {
        final cs = Theme.of(context).colorScheme;

        return Positioned(
          left: offset.dx,
          top: offset.dy + renderBox.size.height + 6,
          width: 240,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: cs.outline, width: 1),
              ),
              child: models.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        "No Models found",
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface,
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: models.map((model) {
                        return InkWell(
                          onTap: () {
                            widget.onSelect(model);
                            _removeOverlay();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            child: Row(
                              children: [
                                Icon(BootstrapIcons.file_code,
                                    size: 13, color: cs.onSurface),
                                const SizedBox(width: 8),
                                Text(model,
                                    style: TextStyle(
                                        color: cs.onSurface, fontSize: 13)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
    setState(() => isOpen = true);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => isOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: _toggleDropdown,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: cs.outline, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(BootstrapIcons.cloud_download, size: 14, color: cs.onPrimary),
            const SizedBox(width: 8),
            Text(
              widget.selectedModel,
              style: TextStyle(color: cs.onPrimary, fontSize: 13),
            ),
            const SizedBox(width: 4),
            Icon(
              isOpen
                  ? BootstrapIcons.caret_up_fill
                  : BootstrapIcons.caret_down_fill,
              size: 12,
              color: cs.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
