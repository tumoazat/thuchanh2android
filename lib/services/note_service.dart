import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';

class NoteService {
  static const String _storageKey = 'notes_list';

  /// Load all notes from SharedPreferences
  Future<List<Note>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList
        .map((item) => Note.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Save all notes to SharedPreferences
  Future<void> saveNotes(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(notes.map((n) => n.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  /// Add a new note
  Future<List<Note>> addNote(Note note) async {
    final notes = await loadNotes();
    notes.insert(0, note);
    await saveNotes(notes);
    return notes;
  }

  /// Update an existing note
  Future<List<Note>> updateNote(Note updatedNote) async {
    final notes = await loadNotes();
    final index = notes.indexWhere((n) => n.id == updatedNote.id);
    if (index != -1) {
      notes[index] = updatedNote;
    }
    await saveNotes(notes);
    return notes;
  }

  /// Delete a note by id
  Future<List<Note>> deleteNote(String id) async {
    final notes = await loadNotes();
    notes.removeWhere((n) => n.id == id);
    await saveNotes(notes);
    return notes;
  }
}
