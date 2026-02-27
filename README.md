# Smart Note - Ứng Dụng Ghi Chú Thông Minh

**Bài thực hành 2 - Android**

## 📋 Mục Lục
- [Giới Thiệu](#giới-thiệu)
- [Tính Năng](#tính-năng)
- [Cấu Trúc Dự Án](#cấu-trúc-dự-án)
- [Công Nghệ Sử Dụng](#công-nghệ-sử-dụng)
- [Hướng Dẫn Cài Đặt](#hướng-dẫn-cài-đặt)
- [Hướng Dẫn Sử Dụng](#hướng-dẫn-sử-dụng)

---

## 🎯 Giới Thiệu

**Smart Note** là một ứng dụng ghi chú di động được xây dựng bằng **Flutter**. Ứng dụng cho phép người dùng:
- Tạo, chỉnh sửa và xóa ghi chú
- Tìm kiếm ghi chú theo từ khóa
- Lưu trữ dữ liệu cục bộ một cách an toàn
- Sắp xếp ghi chú theo thời gian chỉnh sửa

---

## ✨ Tính Năng

### 🏠 Màn Hình Chính (Home Screen)
- Hiển thị danh sách tất cả ghi chú dưới dạng lưới (Grid View)
- Sắp xếp ghi chú theo thời gian chỉnh sửa gần nhất
- Tìm kiếm ghi chú theo tiêu đề hoặc nội dung thời gian thực
- Nút "+" để tạo ghi chú mới
- Xóa ghi chú bằng cách vuốt sang trái/phải

### ✏️ Màn Hình Chỉnh Sửa (Edit Screen)
- Nhập tiêu đề và nội dung ghi chú
- Lưu ghi chú tự động khi quay lại
- Xóa ghi chú

### 🎴 Thẻ Ghi Chú (Note Card)
- Hiển thị tiêu đề và nội dung tóm tắt
- Hiển thị ngày giờ chỉnh sửa cuối cùng
- Màu nền ngẫu nhiên (pastel) dựa trên ID ghi chú

---

## 📁 Cấu Trúc Dự Án

```
lib/
├── main.dart                    # Entry point
├── models/
│   └── note.dart               # Model dữ liệu ghi chú
├── services/
│   └── note_service.dart       # Service xử lý dữ liệu (CRUD)
├── screens/
│   ├── home_screen.dart        # Màn hình chính
│   └── edit_screen.dart        # Màn hình chỉnh sửa ghi chú
└── widgets/
    └── note_card.dart          # Widget hiển thị ghi chú
```

---

## 🛠️ Công Nghệ Sử Dụng

### Framework & SDK
- **Flutter:** 3.10.7+
- **Dart:** 3.10.7+
- **Target:** Android

### Dependencies (Thư Viện)
```yaml
- flutter:                      # Framework chính
- shared_preferences: ^2.2.2   # Lưu trữ dữ liệu cục bộ
- intl: ^0.19.0                # Định dạng ngày tháng
- flutter_staggered_grid_view: ^0.7.0  # Grid view dạng xếp lầu
- cupertino_icons: ^1.0.8      # Icon Cupertino
```

---

## 🔑 Thành Phần Chính

### 1. **Note Model** (lib/models/note.dart)
```dart
class Note {
  final String id;              // ID duy nhất
  String title;                 // Tiêu đề
  String content;               // Nội dung
  DateTime modifiedTime;        // Thời gian chỉnh sửa
}
```

### 2. **NoteService** (lib/services/note_service.dart)
Xử lý tất cả các hoạt động CRUD với SharedPreferences:
- `loadNotes()` - Tải tất cả ghi chú
- `saveNotes()` - Lưu ghi chú
- `addNote()` - Thêm ghi chú mới
- `updateNote()` - Cập nhật ghi chú
- `deleteNote()` - Xóa ghi chú

### 3. **HomeScreen** (lib/screens/home_screen.dart)
Màn hình chính với:
- Danh sách ghi chú dạng grid
- Thanh tìm kiếm thời gian thực
- Nút tạo ghi chú mới

### 4. **EditScreen** (lib/screens/edit_screen.dart)
Cho phép:
- Nhập tiêu đề & nội dung
- Lưu ghi chú
- Xóa ghi chú

### 5. **NoteCard** (lib/widgets/note_card.dart)
Widget hiển thị ghi chú với:
- Màu nền ngẫu nhiên (pastel)
- Thông tin ngày giờ

---

## 💾 Lưu Trữ Dữ Liệu

- **Công nghệ:** SharedPreferences (Local Storage)
- **Định dạng:** JSON
- **Khóa lưu trữ:** `notes_list`

---

