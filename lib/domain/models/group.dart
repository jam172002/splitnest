class Group {
  final String id;
  final String name;
  final String createdBy;
  final bool requireApproval;
  final bool adminBypass;

  Group({
    required this.id,
    required this.name,
    required this.createdBy,
    this.requireApproval = true,
    this.adminBypass = true,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'createdBy': createdBy,
    'requireApproval': requireApproval,
    'adminBypass': adminBypass,
    'createdAt': DateTime.now().toIso8601String(),
  };

  factory Group.fromMap(String id, Map<String, dynamic> m) => Group(
    id: id,
    name: (m['name'] ?? '') as String,
    createdBy: (m['createdBy'] ?? '') as String,
    requireApproval: (m['requireApproval'] ?? true) as bool,
    adminBypass: (m['adminBypass'] ?? true) as bool,
  );
}
