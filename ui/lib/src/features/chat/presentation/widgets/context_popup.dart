import 'package:flutter/material.dart';

class ContextDebugPopup extends StatelessWidget {
  final List<Map<String, String>> contextList;

  const ContextDebugPopup({super.key, required this.contextList});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: cs.surface,
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outline, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  "LLM Context (Debug)",
                  style: textTheme.titleMedium!.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: cs.onSurface),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),

            const SizedBox(height: 10),

            // Scrollable context list
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.3),
                  border: Border.all(color: cs.outline),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ListView.separated(
                  itemCount: contextList.length,
                  separatorBuilder: (_, __) => Divider(
                    color: cs.outline.withOpacity(0.4),
                  ),
                  itemBuilder: (_, i) {
                    final entry = contextList[i];
                    final role = entry["role"] ?? "";
                    final message = entry["message"] ?? "";

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Role tag
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: role == "assistant"
                                  ? cs.primary.withOpacity(0.18)
                                  : role == "system"
                                      ? cs.tertiary.withOpacity(0.18)
                                      : cs.secondary.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          const SizedBox(height: 6),

                          // Message text
                          SelectableText(
                            message,
                            style: textTheme.bodyMedium!.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
