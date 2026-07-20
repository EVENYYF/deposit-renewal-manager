import 'package:flutter/material.dart';

final class EditableCatalogOption {
  const EditableCatalogOption(
    this.value, {
    required this.id,
    this.subtitle,
    this.emphasized = false,
  });

  final String id;
  final String value;
  final String? subtitle;
  final bool emphasized;
}

class EditableCatalogField extends StatefulWidget {
  const EditableCatalogField({
    required this.controller,
    required this.label,
    required this.options,
    required this.onChanged,
    required this.onSelected,
    this.fieldKey,
    this.keyboardType,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final List<EditableCatalogOption> options;
  final ValueChanged<String> onChanged;
  final ValueChanged<EditableCatalogOption> onSelected;
  final Key? fieldKey;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  State<EditableCatalogField> createState() => _EditableCatalogFieldState();
}

class _EditableCatalogFieldState extends State<EditableCatalogField> {
  final _focusNode = FocusNode();
  bool _showAll = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final menuWidth = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : 320.0;
      return MenuAnchor(
        consumeOutsideTap: true,
        menuChildren: [
          for (final option in _visibleOptions)
            MenuItemButton(
              onPressed: () => _select(option),
              child: SizedBox(
                width: menuWidth - 32,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.value,
                      key: Key('catalog-option-${option.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: option.emphasized
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        fontWeight: option.emphasized ? FontWeight.w600 : null,
                      ),
                    ),
                    if (option.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        option.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: option.emphasized
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
        builder: (context, menuController, child) => TextFormField(
          key: widget.fieldKey,
          controller: widget.controller,
          focusNode: _focusNode,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          decoration: InputDecoration(
            labelText: widget.label,
            suffixIcon: IconButton(
              tooltip: '展开${widget.label}选项',
              onPressed: widget.options.isEmpty
                  ? null
                  : () {
                      if (menuController.isOpen) {
                        menuController.close();
                      } else {
                        setState(() => _showAll = true);
                        menuController.open();
                        _focusNode.requestFocus();
                      }
                    },
              icon: Icon(
                menuController.isOpen
                    ? Icons.arrow_drop_up
                    : Icons.arrow_drop_down,
              ),
            ),
          ),
          onTap: () {
            if (widget.options.isNotEmpty && !menuController.isOpen) {
              menuController.open();
            }
          },
          onChanged: (value) {
            setState(() => _showAll = false);
            widget.onChanged(value);
          },
        ),
      );
    },
  );

  List<EditableCatalogOption> get _visibleOptions {
    final query = widget.controller.text.trim().toLowerCase();
    if (_showAll || query.isEmpty) return widget.options;
    return widget.options
        .where((option) => option.value.toLowerCase().contains(query))
        .toList(growable: false);
  }

  void _select(EditableCatalogOption option) {
    widget.controller
      ..text = option.value
      ..selection = TextSelection.collapsed(offset: option.value.length);
    setState(() => _showAll = false);
    widget.onSelected(option);
  }
}
