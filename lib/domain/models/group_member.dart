class GroupMember {
  final String uid;
  final String email;
  final String role; // admin | member
  final DateTime joinedAt;

  GroupMember({
    required this.uid,
    required this.email,
    required this.role,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'role': role,
    'joinedAt': joinedAt.toIso8601String(),
  };

  factory GroupMember.fromMap(Map<String, dynamic> m) => GroupMember(
    uid: (m['uid'] ?? '') as String,
    email: (m['email'] ?? '') as String,
    role: (m['role'] ?? 'member') as String,
    joinedAt: DateTime.tryParse((m['joinedAt'] ?? '') as String) ??
        DateTime.now(),
  );
}
