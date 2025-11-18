import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';

class ModelDropdown extends StatefulWidget {
  const ModelDropdown({super.key});

  @override
  State<ModelDropdown> createState() => _ModelDropdownState();
}

class _ModelDropdownState extends State<ModelDropdown> {
  bool isOpen = false;

  final List<String> models = [
    "openai/gpt-oss-20b",
    "openai/gpt-mini-3b",
    "qwen/qwen2.5-1.5b",
    "phi/phi-3-mini",
  ];

  String selectedModel = "openai/gpt-oss-20b";

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => setState(() => isOpen = !isOpen),
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
                Icon(BootstrapIcons.cloud_download,
                    size: 14, color: cs.onPrimary),
                const SizedBox(width: 8),
                Text(selectedModel,
                    style: TextStyle(color: cs.onPrimary, fontSize: 13)),
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
        ),

        if (isOpen)
          Positioned(
            top: 36,
            left: 0,
            child: Container(
              width: 240,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: cs.outline, width: 1),
              ),
              child: Column(
                children: models.map((model) {
                  return InkWell(
                    onTap: () {
                      setState(() {
                        selectedModel = model;
                        isOpen = false;
                      });
                    },
                    child: Container(
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
      ],
    );
  }
}
