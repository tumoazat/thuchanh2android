import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/note_service.dart';

class EditScreen extends StatefulWidget {
  final Note? note;

  const EditScreen({super.key, this.note});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final NoteService _noteService = NoteService();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late String _noteId;
  bool _isNewNote = false;

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _noteId = widget.note!.id;
      _titleController = TextEditingController(text: widget.note!.title);
      _contentController = TextEditingController(text: widget.note!.content);
    } else {
      _isNewNote = true;
      _noteId = DateTime.now().millisecondsSinceEpoch.toString();
      _titleController = TextEditingController();
      _contentController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// Auto-save: called when user presses back
  Future<bool> _onWillPop() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // If both fields are empty, don't save
    if (title.isEmpty && content.isEmpty) {
      if (_isNewNote) {
        Navigator.pop(context, false);
        return false;
      }
      // If editing existing note and cleared everything, delete it
      await _noteService.deleteNote(_noteId);
      if (mounted) Navigator.pop(context, true);
      return false;
    }

    final note = Note(
      id: _noteId,
      title: title,
      content: content,
      modifiedTime: DateTime.now(),
    );

    if (_isNewNote) {
      await _noteService.addNote(note);
    } else {
      await _noteService.updateNote(note);
    }

    if (mounted) Navigator.pop(context, true);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNewNote ? 'Ghi chú mới' : 'Chỉnh sửa'),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _onWillPop,
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              // Title field
              TextField(
                controller: _titleController,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: 'Tiêu đề',
                  hintStyle: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                  border: InputBorder.none,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              // Content field
              Expanded(
                child: TextField(
                  controller: _contentController,
                  style: const TextStyle(fontSize: 16, height: 1.6),
                  decoration: const InputDecoration(
                    hintText: 'Nội dung ghi chú...',
                    hintStyle: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
