import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
  });

  /// Pick a soft pastel color based on the note id hash
  Color _cardColor(BuildContext context) {
    final colors = [
      const Color(0xFFFFF9C4), // yellow
      const Color(0xFFB3E5FC), // light blue
      const Color(0xFFC8E6C9), // green
      const Color(0xFFF8BBD0), // pink
      const Color(0xFFD1C4E9), // purple
      const Color(0xFFFFCCBC), // orange
      const Color(0xFFCFD8DC), // blue grey
      const Color(0xFFE1BEE7), // light purple
    ];
    final index = note.id.hashCode.abs() % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatted =
        DateFormat('dd/MM/yyyy HH:mm').format(note.modifiedTime);
    final cardColor = _cardColor(context);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              if (note.title.isNotEmpty)
                Text(
                  note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              if (note.title.isNotEmpty) const SizedBox(height: 6),

              // Content preview
              if (note.content.isNotEmpty)
                Text(
                  note.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              if (note.content.isNotEmpty) const SizedBox(height: 10),

              // Date
              Text(
                dateFormatted,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
