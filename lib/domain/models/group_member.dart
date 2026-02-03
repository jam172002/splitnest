import 'package:cloud_firestore/cloud_firestore.dart';

class GroupMember {
  final String id;          // Firestore document ID
  final String name;
  final String? email;      // ← NEW: optional email
  final String role;        // 'admin' or 'member' (or others in future)
  final DateTime joinedAt;

  GroupMember({
    required this.id,
    required this.name,
    this.email,             // ← NEW: optional
    required this.role,
    required this.joinedAt,
  });

  factory GroupMember.fromMap({
    required String id,
    required Map<String, dynamic> map,
  }) {
    return GroupMember(
      id: id,
      name: _parseString(map['name'], defaultValue: 'Unknown Member'),
      email: map['email'] as String?,  // ← NEW: read email if present
      role: _parseString(map['role'], defaultValue: 'member'),
      joinedAt: _parseDateTime(map['joinedAt']) ?? DateTime.now(),
    );
  }

  // Safe string parsing helper
  static String _parseString(dynamic value, {required String defaultValue}) {
    if (value == null) return defaultValue;
    if (value is String) return value.trim().isNotEmpty ? value.trim() : defaultValue;
    return defaultValue;
  }

  // Safe datetime parsing helper (handles Timestamp, String, null, etc.)
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    // Most common case: proper Firestore Timestamp
    if (value is Timestamp) {
      return value.toDate();
    }

    // Problematic case: string (your current issue)
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;

      // Try to handle common wrong formats (e.g. "2025-01-15" without time)
      try {
        return DateTime.parse(value.replaceAll('/', '-').replaceAll(' ', 'T'));
      } catch (_) {
        // Log once so you know which documents are broken
        print('Invalid joinedAt string in document: "$value"');
        return null;
      }
    }

    // Rare case: someone saved as milliseconds
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (_) {}
    }

    // If nothing works
    print('Unsupported joinedAt type: ${value.runtimeType} → value: $value');
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'email': email,          // ← NEW: include email if present
      'role': role.trim().toLowerCase(),
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  // ────────────────────────────────────────────────
  // Helpful getters / computed properties
  // ────────────────────────────────────────────────

  String get displayName => name.trim();

  String get initials {
    if (name.trim().isEmpty) return '?';
    return name.trim()[0].toUpperCase();
  }

  bool get isAdmin => role.toLowerCase() == 'admin';

  String get roleDisplay {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'member':
        return 'Member';
      default:
        return role;
    }
  }

  // Optional: for easier debugging
  @override
  String toString() {
    return 'GroupMember(id: $id, name: "$name", email: $email, role: $role, joined: $joinedAt)';
  }
}