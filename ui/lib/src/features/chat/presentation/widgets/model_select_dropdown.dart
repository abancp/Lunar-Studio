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
  bool isLoading = true;
  final LayerLink _layerLink = LayerLink();

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
    try {
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
        models.add("Import Model");
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
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
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => _DropdownOverlay(
        layerLink: _layerLink,
        buttonWidth: size.width,
        models: models,
        selectedModel: widget.selectedModel,
        onSelect: (model) {
          widget.onSelect(model);
          _removeOverlay();
        },
        onDismiss: _removeOverlay,
      ),
    );

    overlay.insert(_overlayEntry!);
    setState(() => isOpen = true);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => isOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isOpen ? cs.onPrimary.withOpacity(0.3) : cs.outline,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                BootstrapIcons.cloud_download,
                size: 16,
                color: cs.onPrimary,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.selectedModel,
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isOpen
                    ? BootstrapIcons.chevron_up
                    : BootstrapIcons.chevron_down,
                size: 14,
                color: cs.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownOverlay extends StatefulWidget {
  final LayerLink layerLink;
  final double buttonWidth;
  final List<String> models;
  final String selectedModel;
  final ValueChanged<String> onSelect;
  final VoidCallback onDismiss;

  const _DropdownOverlay({
    required this.layerLink,
    required this.buttonWidth,
    required this.models,
    required this.selectedModel,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<_DropdownOverlay> createState() => _DropdownOverlayState();
}

class _DropdownOverlayState extends State<_DropdownOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final maxWidth = screenSize.width * 0.9;
    final minWidth = widget.buttonWidth;
    final dropdownWidth = minWidth.clamp(280.0, maxWidth);

    return GestureDetector(
      onTap: widget.onDismiss,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // Backdrop
          Container(color: Colors.transparent),
          
          // Dropdown menu
          CompositedTransformFollower(
            link: widget.layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, 44),
            child: Align(
              alignment: Alignment.topLeft,
              child: FadeTransition(
                opacity: _animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1.0).animate(_animation),
                  alignment: Alignment.topCenter,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    shadowColor: cs.shadow.withOpacity(0.3),
                    child: Container(
                      width: dropdownWidth,
                      constraints: BoxConstraints(
                        maxHeight: screenSize.height * 0.5,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cs.outline.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: widget.models.isEmpty
                            ? _buildEmptyState(cs)
                            : _buildModelList(cs),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            BootstrapIcons.inbox,
            size: 48,
            color: cs.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            "No Models Found",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Import a model to get started",
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelList(ColorScheme cs) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.models.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 0.5,
        color: cs.outline.withOpacity(0.1),
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (context, index) {
        final model = widget.models[index];
        final isSelected = model == widget.selectedModel;
        final isImportAction = model == "Import Model";

        return InkWell(
          onTap: () => widget.onSelect(model),
          hoverColor: cs.primary.withOpacity(0.08),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? cs.primary.withOpacity(0.1)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isImportAction
                        ? cs.primaryContainer
                        : cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isImportAction
                        ? BootstrapIcons.plus_circle
                        : BootstrapIcons.file_earmark_code,
                    size: 16,
                    color: isImportAction
                        ? cs.onPrimaryContainer
                        : cs.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (!isImportAction) ...[
                        const SizedBox(height: 2),
                        Text(
                          "GGUF Model",
                          style: TextStyle(
                            color: cs.onSurface.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    BootstrapIcons.check_circle_fill,
                    size: 18,
                    color: cs.primary,
                  ),
                if (isImportAction && !isSelected)
                  Icon(
                    BootstrapIcons.arrow_right_short,
                    size: 20,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}