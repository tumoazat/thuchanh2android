import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource, XFile;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

// ============================================================================
// 📝 Simple Note App — Material Design 3 (Material You)
// ============================================================================
// Tính năng:
//   • Thêm, sửa, xóa ghi chú
//   • Tìm kiếm ghi chú (Search)
//   • Thêm hình ảnh vào ghi chú
//   • Hero animation, micro-interactions
//   • Dark mode hỗ trợ Material 3
//   • Empty state với animation tinh tế
//   • Smooth transitions & elevation animation
// ============================================================================

void main() {
  runApp(const SimpleNoteApp());
}

// ========================== APP ROOT =========================================

/// Widget gốc của ứng dụng, hỗ trợ chuyển đổi Light / Dark mode.
class SimpleNoteApp extends StatefulWidget {
  const SimpleNoteApp({super.key});

  @override
  State<SimpleNoteApp> createState() => _SimpleNoteAppState();
}

class _SimpleNoteAppState extends State<SimpleNoteApp> {
  /// Trạng thái dark mode — mặc định theo hệ thống
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Seed color dùng để tạo dynamic color palette theo M3
    const seedColor = Color(0xFF6750A4);

    return MaterialApp(
      title: 'Simple Note App',
      debugShowCheckedModeBanner: false,

      // — Light theme —
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
      ),

      // — Dark theme —
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
      ),

      themeMode: _themeMode,

      home: HomeScreen(
        onToggleTheme: _toggleTheme,
        themeMode: _themeMode,
      ),
    );
  }
}

// ========================== NOTE MODEL =======================================

/// Model đại diện cho một ghi chú.
class NoteModel {
  /// ID duy nhất (dùng timestamp milliseconds)
  final int id;

  /// Tiêu đề ghi chú
  String title;

  /// Nội dung ghi chú
  String content;

  /// Ngày tạo
  final DateTime createdAt;

  /// Màu nhấn (tuỳ chọn) — index trong bảng màu
  int colorIndex;

  /// Path hình ảnh (nếu có)
  String? imagePath;
  
  /// List các file đính kèm (PDF, Word, Excel, etc.)
  List<String>? attachmentPaths;

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.colorIndex = 0,
    this.imagePath,
    this.attachmentPaths,
  });

  /// Tạo bản copy với các trường thay đổi
  NoteModel copyWith({
    String? title,
    String? content,
    int? colorIndex,
    String? imagePath,
    List<String>? attachmentPaths,
  }) {
    return NoteModel(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      colorIndex: colorIndex ?? this.colorIndex,
      imagePath: imagePath ?? this.imagePath,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
    );
  }
  
  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'colorIndex': colorIndex,
      'imagePath': imagePath,
      'attachmentPaths': attachmentPaths,
    };
  }
  
  /// Create from JSON
  factory NoteModel.fromJson(Map<String, dynamic> json) => NoteModel(
    id: json['id'] as int,
    title: json['title'] as String,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    colorIndex: json['colorIndex'] as int? ?? 0,
    imagePath: json['imagePath'] as String?,
    attachmentPaths: (json['attachmentPaths'] as List?)?.cast<String>(),
  );
}

// ========================== HOME SCREEN ======================================

/// Màn hình chính — hiển thị danh sách ghi chú.
class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;

  const HomeScreen({
    super.key,
    required this.onToggleTheme,
    required this.themeMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  /// Danh sách ghi chú
  final List<NoteModel> _notes = [];

  /// Text controller cho search
  final _searchCtrl = TextEditingController();

  /// Query tìm kiếm hiện tại
  String _searchQuery = '';

  /// Controller cho animation empty state
  late final AnimationController _emptyAnimCtrl;
  late final Animation<double> _emptyFadeAnim;
  late final Animation<double> _emptyScaleAnim;

  /// Controller cho FAB scale on scroll
  late final AnimationController _fabScaleCtrl;
  late final Animation<double> _fabScaleAnim;

  /// Controller cho search bar
  late final AnimationController _searchAnimCtrl;
  late final Animation<double> _searchSlideAnim;

  /// Scroll controller để track scroll
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();

    // ========== Empty State Animation ==========
    // Icon: scale 0.8 → 1.0 + fade
    _emptyAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _emptyScaleAnim = CurvedAnimation(
      parent: _emptyAnimCtrl,
      curve: Curves.easeOutCubic,
    );

    _emptyFadeAnim = CurvedAnimation(
      parent: _emptyAnimCtrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeInOutCubic),
    );

    // ========== FAB Scale Animation ==========
    _fabScaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fabScaleAnim = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _fabScaleCtrl, curve: Curves.easeInOutCubic),
    );

    // ========== Search Bar Animation ==========
    _searchAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _searchSlideAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _searchAnimCtrl, curve: Curves.easeOutCubic),
    );

    // ========== Scroll Controller ==========
    _scrollCtrl = ScrollController();
    _scrollCtrl.addListener(_onScrollChange);

    // Phát animation lần đầu nếu danh sách rỗng
    if (_notes.isEmpty) _emptyAnimCtrl.forward();

    // Listen search text
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.toLowerCase().trim();
      });
    });
    
    // Load notes from storage
    _loadNotes();
  }
  
  /// Load notes from SharedPreferences
  Future<void> _loadNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('notes_list');
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        setState(() {
          _notes.clear();
          _notes.addAll(
            jsonList.map((item) => NoteModel.fromJson(item as Map<String, dynamic>))
          );
        });
      }
    } catch (e) {
      debugPrint('Error loading notes: $e');
    }
  }
  
  /// Save notes to SharedPreferences
  Future<void> _saveNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(_notes.map((n) => n.toJson()).toList());
      await prefs.setString('notes_list', jsonString);
    } catch (e) {
      debugPrint('Error saving notes: $e');
    }
  }

  /// Xử lý FAB scale khi scroll
  void _onScrollChange() {
    // Kiểm tra scroll position — FAB shrink khi scroll down
    if (!_scrollCtrl.hasClients) return;
    
    final maxScroll = _scrollCtrl.position.maxScrollExtent;
    final currentScroll = _scrollCtrl.offset;
    
    // Nếu chưa ở cuối danh sách, FAB scale down khi scroll
    if (currentScroll < maxScroll * 0.9) {
      if (_fabScaleCtrl.status != AnimationStatus.reverse) {
        _fabScaleCtrl.reverse();
      }
    } else {
      if (_fabScaleCtrl.status != AnimationStatus.forward) {
        _fabScaleCtrl.forward();
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _emptyAnimCtrl.dispose();
    _fabScaleCtrl.dispose();
    _searchAnimCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ---------- NAVIGATION HELPERS ----------

  /// Mở màn hình thêm ghi chú — nhận kết quả qua Future + await.
  Future<void> _navigateToAddNote() async {
    final NoteModel? newNote = await Navigator.push<NoteModel>(
      context,
      _buildPageRoute(const AddNoteScreen()),
    );

    if (newNote != null) {
      setState(() {
        _notes.insert(0, newNote); // Thêm đầu danh sách
      });
      // Ẩn empty state animation
      _emptyAnimCtrl.reset();
      // Save to storage
      await _saveNotes();
    }
  }

  /// Mở màn hình sửa ghi chú.
  Future<void> _navigateToEditNote(NoteModel note, int index) async {
    final NoteModel? updatedNote = await Navigator.push<NoteModel>(
      context,
      _buildPageRoute(EditNoteScreen(note: note)),
    );

    if (updatedNote != null) {
      setState(() {
        _notes[index] = updatedNote;
      });
      // Save to storage
      await _saveNotes();
    }
  }

  /// Xoá ghi chú với xác nhận AlertDialog.
  Future<void> _deleteNote(int index) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever_rounded),
        title: const Text('Xoá ghi chú?'),
        content: const Text(
          'Bạn có chắc muốn xoá ghi chú này không?\nHành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _notes.removeAt(index);
      });
      
      // Save to storage
      await _saveNotes();

      // Nếu hết note → chạy lại animation empty state
      if (_notes.isEmpty) {
        _emptyAnimCtrl.forward(from: 0);
      }
    }
  }

  /// Tạo custom PageRoute với shared axis transition (Material Motion).
  /// Dùng slide + fade với easeInOutCubic curve.
  Route<T> _buildPageRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        /// Shared axis transition: Slide vertical (Y axis) + Fade
        /// Curve: easeInOutCubic (tuân theo M3 guidelines)
        final tween = Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        );
        final offsetAnimation = animation.drive(
          tween.chain(CurveTween(curve: Curves.easeInOutCubic)),
        );

        return FadeTransition(
          opacity: animation.drive(
            CurveTween(curve: Curves.easeInOutCubic),
          ),
          child: SlideTransition(
            position: offsetAnimation,
            child: child,
          ),
        );
      },
    );
  }

  // ---------- BUILD ----------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = widget.themeMode == ThemeMode.dark;

    return Scaffold(
      // — AppBar —
      appBar: AppBar(
        title: const Text('Simple Note App'),
        centerTitle: true,
        actions: [
          // Nút chuyển đổi dark / light mode
          IconButton(
            tooltip:
                isDark ? 'Chuyển sang Light mode' : 'Chuyển sang Dark mode',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) =>
                  RotationTransition(turns: anim, child: child),
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                key: ValueKey(isDark),
              ),
            ),
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 4),
        ],
      ),

      // — Body —
      body: _buildBody(cs),

      // — FAB Extended — với scale animation khi scroll
      floatingActionButton: ScaleTransition(
        scale: _fabScaleAnim,
        alignment: Alignment.bottomRight,
        child: FloatingActionButton.extended(
          onPressed: _navigateToAddNote,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Thêm ghi chú'),
          elevation: 4,
        ),
      ),
    );
  }

  /// Build body — hiển thị search bar + danh sách / empty state
  Widget _buildBody(ColorScheme cs) {
    // Filter notes theo search query
    final filteredNotes = _searchQuery.isEmpty
        ? _notes
        : _notes
            .where((note) =>
                note.title.toLowerCase().contains(_searchQuery) ||
                note.content.toLowerCase().contains(_searchQuery))
            .toList();

    return Column(
      children: [
        // — Search Bar —
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _buildSearchBar(cs),
        ),

        // — Note List / Empty State —
        Expanded(
          child: filteredNotes.isEmpty
              ? _buildEmptyState(cs, _searchQuery.isNotEmpty)
              : _buildNoteList(cs, filteredNotes),
        ),
      ],
    );
  }

  /// Build search bar với animation
  Widget _buildSearchBar(ColorScheme cs) {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Tìm kiếm ghi chú...',
        hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
        prefixIcon: Icon(Icons.search_rounded,
            color: cs.onSurface.withValues(alpha: 0.5)),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.close_rounded,
                    color: cs.onSurface.withValues(alpha: 0.5)),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      style: const TextStyle(fontSize: 16),
    );
  }

  /// Widget hiển thị khi không có ghi chú.
  /// Animation: Icon scale 0.8→1.0 + Fade, Text delayed
  Widget _buildEmptyState(ColorScheme cs, [bool isSearchEmpty = false]) {
    final title = isSearchEmpty ? 'Không tìm thấy ghi chú' : 'Chưa có ghi chú nào';
    final subtitle = isSearchEmpty
        ? 'Thử tìm kiếm từ khác hoặc tạo ghi chú mới'
        : 'Nhấn nút bên dưới để tạo ghi chú mới!';
    final iconData = isSearchEmpty ? Icons.search_off_rounded : Icons.note_alt_outlined;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // — Icon: Scale + Fade —
          ScaleTransition(
            scale: _emptyScaleAnim,
            child: FadeTransition(
              opacity: _emptyFadeAnim,
              child: Icon(
                iconData,
                size: 96,
                color: cs.primary.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // — Text: Delayed fade (starts at 30% của animation) —
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _emptyAnimCtrl,
              curve: const Interval(0.3, 1.0, curve: Curves.easeInOutCubic),
            ),
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Danh sách ghi chú dạng ListView.builder (smooth add/remove)
  Widget _buildNoteList(ColorScheme cs, List<NoteModel> notes) {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        // Tìm index gốc để sửa/xóa trong danh sách chính
        final originalIndex = _notes.indexOf(note);
        return _NoteCardWithDelete(
          key: ValueKey(note.id),
          note: note,
          onTap: () => _navigateToEditNote(note, originalIndex),
          onDelete: () => _deleteNote(originalIndex),
        );
      },
    );
  }
}

// ========================== NOTE CARD WITH DELETE =============================

/// Wrapper cho NoteCard với delete animation (slide right + fade + shrink height)
class _NoteCardWithDelete extends StatefulWidget {
  final NoteModel note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCardWithDelete({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_NoteCardWithDelete> createState() => _NoteCardWithDeleteState();
}

class _NoteCardWithDeleteState extends State<_NoteCardWithDelete>
    with SingleTickerProviderStateMixin {
  late final AnimationController _deleteCtrl;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _heightAnim;

  @override
  void initState() {
    super.initState();
    _deleteCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    // Slide right: 0 → 1 (card moves right)
    _slideAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _deleteCtrl, curve: Curves.easeInOutCubic),
    );

    // Fade: 1 → 0
    _fadeAnim = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _deleteCtrl, curve: Curves.easeInOutCubic),
    );

    // Height: 1 → 0 (shrink)
    _heightAnim = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _deleteCtrl,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInCubic),
      ),
    );
  }

  @override
  void dispose() {
    _deleteCtrl.dispose();
    super.dispose();
  }

  /// Trigger delete animation
  Future<void> _triggerDelete() async {
    await _deleteCtrl.forward();
    widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset.zero, end: const Offset(0.3, 0))
            .animate(_slideAnim),
        child: SizeTransition(
          sizeFactor: _heightAnim,
          axis: Axis.vertical,
          axisAlignment: -1,
          child: NoteCard(
            note: widget.note,
            onTap: widget.onTap,
            onDelete: _triggerDelete,
          ),
        ),
      ),
    );
  }
}

// ========================== NOTE CARD ========================================

/// Bảng màu accent nhẹ cho các note card — tạo sự đa dạng.
const List<Color> _noteAccentColors = [
  Color(0xFF6750A4), // Purple (seed)
  Color(0xFF0288D1), // Blue
  Color(0xFF00897B), // Teal
  Color(0xFFE65100), // Deep Orange
  Color(0xFFC62828), // Red
  Color(0xFF558B2F), // Light Green
  Color(0xFF6D4C41), // Brown
];

/// Widget hiển thị một ghi chú trong danh sách — có micro-interaction.
class NoteCard extends StatefulWidget {
  final NoteModel note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  /// Trạng thái nhấn cho scale animation (micro-interaction)
  bool _pressed = false;

  /// Elevation animation state
  bool _hovered = false;

  /// Elevation tween
  late final Tween<double> _elevationTween;

  @override
  void initState() {
    super.initState();
    _elevationTween = Tween<double>(begin: 2, end: 8);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final note = widget.note;

    // Màu accent theo colorIndex
    final accent =
        _noteAccentColors[note.colorIndex % _noteAccentColors.length];

    // Format ngày tạo
    final dateStr = '${note.createdAt.day.toString().padLeft(2, '0')}/'
        '${note.createdAt.month.toString().padLeft(2, '0')}/'
        '${note.createdAt.year}  '
        '${note.createdAt.hour.toString().padLeft(2, '0')}:'
        '${note.createdAt.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      onLongPress: widget.onDelete,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          // Micro-interaction: Scale khi nhấn (0.98)
          transform: Matrix4.identity()
            ..scale(_pressed ? 0.98 : 1.0, _pressed ? 0.98 : 1.0),
          transformAlignment: Alignment.center,
          margin: const EdgeInsets.only(bottom: 12),
          child: Hero(
            tag: 'note_hero_${note.id}',
            child: Material(
              type: MaterialType.transparency,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOutCubic,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.2),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(
                        alpha: _hovered ? 0.15 : 0.08,
                      ),
                      blurRadius: _hovered ? 16 : 8,
                      offset: Offset(0, _hovered ? 8 : 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    // Ripple effect (natural per M3)
                    onTap: widget.onTap,
                    customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // — Header: title + delete icon —
                          Row(
                            children: [
                              // Accent dot
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Tiêu đề
                              Expanded(
                                child: Text(
                                  note.title,
                                  style: tt.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Delete icon
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: cs.error.withValues(alpha: 0.65),
                                  size: 20,
                                ),
                                onPressed: widget.onDelete,
                                tooltip: 'Xoá ghi chú',
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // — Nội dung —
                          Text(
                            note.content,
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.7),
                              height: 1.45,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),

                          // — Image Thumbnail (nếu có) —
                          if (note.imagePath != null && note.imagePath!.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(note.imagePath!),
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) =>
                                    Container(
                                      height: 120,
                                      color: cs.surfaceContainer,
                                      child: Icon(Icons.broken_image_rounded,
                                          color: cs.onSurface
                                              .withValues(alpha: 0.3)),
                                    ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // — Ngày tạo —
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: cs.onSurface
                                    .withValues(alpha: 0.35),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                dateStr,
                                style: tt.labelSmall?.copyWith(
                                  color: cs.onSurface
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ========================== ADD NOTE SCREEN ===================================

/// Màn hình thêm ghi chú mới — với entry animation mượt.
class AddNoteScreen extends StatefulWidget {
  const AddNoteScreen({super.key});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen>
    with SingleTickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  int _selectedColor = 0;
  
  /// Đường dẫn hình ảnh được chọn
  String? _selectedImagePath;
  
  /// List file đính kèm (PDF, Word, Excel, etc.)
  List<String> _attachmentPaths = [];

  /// Image picker (only for mobile)
  late final ImagePicker? _imagePicker;

  /// Animation controller cho input fields
  late final AnimationController _inputAnimCtrl;
  late final Animation<double> _inputFadeAnim;
  late final Animation<Offset> _inputSlideAnim;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _imagePicker = ImagePicker();
    _inputAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Fade in
    _inputFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _inputAnimCtrl, curve: Curves.easeIn),
    );

    // Slide up
    _inputSlideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: _inputAnimCtrl, curve: Curves.easeOutCubic),
    );

    _inputAnimCtrl.forward();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _inputAnimCtrl.dispose();
    super.dispose();
  }

  /// Lưu ghi chú và trả về cho HomeScreen.
  void _saveNote() {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tiêu đề!')),
      );
      return;
    }

    final note = NoteModel(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      content: content.isEmpty ? 'Không có nội dung' : content,
      createdAt: DateTime.now(),
      colorIndex: _selectedColor,
      imagePath: _selectedImagePath,
      attachmentPaths: _attachmentPaths.isEmpty ? null : _attachmentPaths,
    );

    Navigator.pop(context, note);
  }

  /// Chọn hình ảnh từ gallery
  Future<void> _pickImage() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hình ảnh không hỗ trợ trên web')),
      );
      return;
    }
    try {
      final XFile? image =
          await _imagePicker?.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi chọn hình ảnh: $e')),
      );
    }
  }

  /// Xóa hình ảnh đã chọn
  void _removeImage() {
    setState(() {
      _selectedImagePath = null;
    });
  }
  
  /// Chọn file đính kèm (PDF, Word, Excel, etc.)
  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      
      if (result != null) {
        setState(() {
          _attachmentPaths.addAll(result.paths.whereType<String>());
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi chọn file: $e')),
      );
    }
  }
  
  /// Xóa file đính kèm
  void _removeAttachment(int index) {
    setState(() {
      _attachmentPaths.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm ghi chú'),
        centerTitle: true,
      ),
      body: SlideTransition(
        position: _inputSlideAnim,
        child: FadeTransition(
          opacity: _inputFadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // — Color picker —
                Text('Chọn màu', style: tt.labelLarge),
                const SizedBox(height: 10),
                _ColorPicker(
                  selectedIndex: _selectedColor,
                  onSelect: (i) => setState(() => _selectedColor = i),
                ),
                const SizedBox(height: 24),

                // — Title —
                TextField(
                  controller: _titleCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  style: tt.titleLarge,
                  decoration: InputDecoration(
                    labelText: 'Tiêu đề',
                    hintText: 'Nhập tiêu đề ghi chú...',
                    filled: true,
                    fillColor:
                        cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: cs.primary, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 18),

                // — Content —
                TextField(
                  controller: _contentCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 8,
                  minLines: 4,
                  style: tt.bodyLarge,
                  decoration: InputDecoration(
                    labelText: 'Nội dung',
                    hintText: 'Nhập nội dung ghi chú...',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor:
                        cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: cs.primary, width: 2),
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 80),
                      child: Icon(Icons.notes_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // — Image Section —
                if (_selectedImagePath != null) ...[
                  Text('Hình ảnh đã chọn', style: tt.labelLarge),
                  const SizedBox(height: 10),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(_selectedImagePath!),
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton.filled(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _removeImage,
                          style: IconButton.styleFrom(
                            backgroundColor: cs.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image_rounded),
                    label: const Text('Chọn hình ảnh'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // — Attachments Section —
                if (_attachmentPaths.isNotEmpty) ...[
                  Text('File đính kèm (${_attachmentPaths.length})', style: tt.labelLarge),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _attachmentPaths.length,
                    itemBuilder: (ctx, i) {
                      final filename = _attachmentPaths[i].split('/').last;
                      return ListTile(
                        leading: const Icon(Icons.attach_file_rounded),
                        title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => _removeAttachment(i),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                
                OutlinedButton.icon(
                  onPressed: _pickAttachment,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: const Text('Đính kèm file'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DrawingScreen())),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Vẽ ghi chú'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // — Save button —
                FilledButton.icon(
                  onPressed: _saveNote,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Lưu ghi chú'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========================== EDIT NOTE SCREEN ==================================

/// Màn hình sửa ghi chú — nhận note cũ, trả note đã cập nhật.
class EditNoteScreen extends StatefulWidget {
  final NoteModel note;

  const EditNoteScreen({super.key, required this.note});

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late int _selectedColor;
  
  /// Đường dẫn hình ảnh hiện tại
  String? _selectedImagePath;
  
  /// List file đính kèm (PDF, Word, Excel, etc.)
  late List<String> _attachmentPaths;

  /// Image picker (only for mobile)
  late final ImagePicker? _imagePicker;

  /// Animation controller cho input fields
  late final AnimationController _inputAnimCtrl;
  late final Animation<double> _inputFadeAnim;
  late final Animation<Offset> _inputSlideAnim;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note.title);
    _contentCtrl = TextEditingController(text: widget.note.content);
    _selectedColor = widget.note.colorIndex;
    _selectedImagePath = widget.note.imagePath;
    _attachmentPaths = List<String>.from(widget.note.attachmentPaths ?? []);
    if (!kIsWeb) _imagePicker = ImagePicker();

    _inputAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _inputFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _inputAnimCtrl, curve: Curves.easeIn),
    );

    _inputSlideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: _inputAnimCtrl, curve: Curves.easeOutCubic),
    );

    _inputAnimCtrl.forward();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _inputAnimCtrl.dispose();
    super.dispose();
  }

  /// Cập nhật ghi chú và trả về kết quả.
  void _updateNote() {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tiêu đề không được để trống!')),
      );
      return;
    }

    final updatedNote = widget.note.copyWith(
      title: title,
      content: content.isEmpty ? 'Không có nội dung' : content,
      colorIndex: _selectedColor,
      imagePath: _selectedImagePath,
      attachmentPaths: _attachmentPaths.isEmpty ? null : _attachmentPaths,
    );

    Navigator.pop(context, updatedNote);
  }

  /// Chọn hình ảnh từ gallery
  Future<void> _pickImage() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hình ảnh không hỗ trợ trên web')),
      );
      return;
    }
    try {
      final XFile? image =
          await _imagePicker?.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi chọn hình ảnh: $e')),
      );
    }
  }

  /// Xóa hình ảnh
  void _removeImage() {
    setState(() {
      _selectedImagePath = null;
    });
  }
  
  /// Chọn file đính kèm (PDF, Word, Excel, etc.)
  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      
      if (result != null) {
        setState(() {
          _attachmentPaths.addAll(result.paths.whereType<String>());
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi chọn file: $e')),
      );
    }
  }
  
  /// Xóa file đính kèm
  void _removeAttachment(int index) {
    setState(() {
      _attachmentPaths.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa ghi chú'),
        centerTitle: true,
      ),
      body: SlideTransition(
        position: _inputSlideAnim,
        child: FadeTransition(
          opacity: _inputFadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Hero(
              tag: 'note_hero_${widget.note.id}',
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // — Color picker —
                    Text('Chọn màu', style: tt.labelLarge),
                    const SizedBox(height: 10),
                    _ColorPicker(
                      selectedIndex: _selectedColor,
                      onSelect: (i) => setState(() => _selectedColor = i),
                    ),
                    const SizedBox(height: 24),

                    // — Title —
                    TextField(
                      controller: _titleCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      style: tt.titleLarge,
                      decoration: InputDecoration(
                        labelText: 'Tiêu đề',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: cs.primary, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.title_rounded),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // — Content —
                    TextField(
                      controller: _contentCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 8,
                      minLines: 4,
                      style: tt.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Nội dung',
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: cs.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: cs.primary, width: 2),
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 80),
                          child: Icon(Icons.notes_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // — Image Section —
                    if (_selectedImagePath != null) ...[
                      Text('Hình ảnh', style: tt.labelLarge),
                      const SizedBox(height: 10),
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(_selectedImagePath!),
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton.filled(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: _removeImage,
                              style: IconButton.styleFrom(
                                backgroundColor: cs.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image_rounded),
                        label: const Text('Chọn hình ảnh'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // — Attachments Section —
                    if (_attachmentPaths.isNotEmpty) ...[
                      Text('File đính kèm (${_attachmentPaths.length})', style: tt.labelLarge),
                      const SizedBox(height: 10),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _attachmentPaths.length,
                        itemBuilder: (ctx, i) {
                          final filename = _attachmentPaths[i].split('/').last;
                          return ListTile(
                            leading: const Icon(Icons.attach_file_rounded),
                            title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () => _removeAttachment(i),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    
                    OutlinedButton.icon(
                      onPressed: _pickAttachment,
                      icon: const Icon(Icons.attach_file_rounded),
                      label: const Text('Đính kèm file'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DrawingScreen())),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Vẽ ghi chú'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // — Update button —
                    FilledButton.icon(
                      onPressed: _updateNote,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Cập nhật'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ========================== COLOR PICKER (PRIVATE) ============================

/// Widget nhỏ cho phép chọn màu accent của ghi chú — với animation mượt.
class _ColorPicker extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _ColorPicker({
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: List.generate(_noteAccentColors.length, (i) {
        final isSelected = i == selectedIndex;
        return GestureDetector(
          onTap: () => onSelect(i),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: isSelected ? 1 : 0),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            builder: (context, selectValue, _) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _noteAccentColors[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3 * selectValue,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _noteAccentColors[i].withValues(
                        alpha: 0.4 * selectValue,
                      ),
                      blurRadius: 8 * selectValue,
                      offset: Offset(0, 2 * selectValue),
                    ),
                  ],
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 20 * (0.5 + selectValue * 0.5),
                      )
                    : null,
              );
            },
          ),
        );
      }),
    );
  }
}
// ========================== DRAWING SCREEN ==================================

/// Screen cho phép vẽ/ghi chú tay trực tiếp trên app.
class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  late List<List<Offset>> _strokes;
  late Color _penColor;
  late double _penSize;
  
  @override
  void initState() {
    super.initState();
    _strokes = [];
    _penColor = Colors.black87;
    _penSize = 3.0;
  }
  
  void _clearDrawing() {
    setState(() {
      _strokes.clear();
    });
  }
  
  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
    }
  }
  
  void _saveDrawing() {
    // TODO: Save drawing as image and return to previous screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Drawing feature coming soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vẽ ghi chú'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            onPressed: _undo,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _clearDrawing,
          ),
        ],
      ),
      body: Column(
        children: [
          // Toolbar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kích cỡ nét', style: TextStyle(fontSize: 12)),
                      Slider(
                        value: _penSize,
                        min: 1,
                        max: 10,
                        onChanged: (v) => setState(() => _penSize = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Chọn màu'),
                        content: Wrap(
                          spacing: 8,
                          children: [
                            Colors.black87,
                            Colors.red,
                            Colors.blue,
                            Colors.green,
                          ]
                              .map((color) => GestureDetector(
                                    onTap: () {
                                      setState(() => _penColor = color);
                                      Navigator.pop(ctx);
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _penColor == color
                                              ? Colors.white
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _penColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          
          // Canvas
          Expanded(
            child: GestureDetector(
              onPanStart: (details) {
                setState(() {
                  _strokes.add([details.localPosition]);
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  _strokes.last.add(details.localPosition);
                });
              },
              child: CustomPaint(
                painter: _DrawingPainter(_strokes, _penColor, _penSize),
                size: Size.infinite,
              ),
            ),
          ),
          
          // Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Huỷ'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saveDrawing,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Lưu'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for drawing
class _DrawingPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color penColor;
  final double penSize;
  
  _DrawingPainter(this.strokes, this.penColor, this.penSize);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = penColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = penSize;
    
    for (final stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }
  }
  
  @override
  bool shouldRepaint(_DrawingPainter oldDelegate) => true;
}