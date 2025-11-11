import 'package:flutter/material.dart';

class HoverableListItem extends StatefulWidget {
  final Widget child;

  const HoverableListItem({super.key, required this.child});

  @override
  State<HoverableListItem> createState() => _HoverableListItemState();
}

class _HoverableListItemState extends State<HoverableListItem> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0.0, isHovered ? -2.0 : 0.0, 0.0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isHovered ? 1.0 : 0.85,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isHovered ? colorScheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
