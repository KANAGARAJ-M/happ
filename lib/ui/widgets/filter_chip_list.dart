import 'package:flutter/material.dart';

class FilterChipList extends StatelessWidget {
  final String selected;
  final Map<String, String> options;
  final Function(String) onSelected;

  const FilterChipList({
    super.key,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            options.entries.map((entry) {
              final isSelected = selected == entry.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  selected: isSelected,
                  label: Text(entry.value),
                  onSelected: (_) => onSelected(entry.key),
                  backgroundColor: Colors.grey[200],
                  selectedColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.2),
                  checkmarkColor: Theme.of(context).primaryColor,
                ),
              );
            }).toList(),
      ),
    );
  }
}
