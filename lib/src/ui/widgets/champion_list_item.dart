import 'package:flutter/material.dart';
import '../../models/champion.dart';

class ChampionListItem extends StatefulWidget {
  final Champion champion;
  final VoidCallback onTap;

  const ChampionListItem({
    super.key,
    required this.champion,
    required this.onTap,
  });

  @override
  State<ChampionListItem> createState() => _ChampionListItemState();
}

class _ChampionListItemState extends State<ChampionListItem> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isHovered
              ? colorScheme.primary.withAlpha(20)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isHovered ? colorScheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: ListTile(
          leading: AnimatedScale(
            scale: isHovered ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                widget.champion.imagePath,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 32,
                  height: 32,
                  color: colorScheme.primary,
                  child: Center(
                    child: Text(
                      widget.champion.name[0].toUpperCase(),
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          title: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              color: isHovered ? colorScheme.secondary : colorScheme.onSurface,
              fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
            ),
            child: Text(widget.champion.name),
          ),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}
