class Group {
  final String id;
  final String name;
  final String createdBy;

  /// number of members in this group
  final int membersCount;

  /// require approval for member entries
  final bool requireApproval;

  /// admin entries auto approved
  final bool adminBypass;

  /// "any" | "all" | "admin_only"
  final String approvalMode;

  Group({
    required this.id,
    required this.name,
    required this.createdBy,
    this.membersCount = 1,
    this.requireApproval = true,
    this.adminBypass = true,
    this.approvalMode = 'any',
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'createdBy': createdBy,
    'membersCount': membersCount,
    'requireApproval': requireApproval,
    'adminBypass': adminBypass,
    'approvalMode': approvalMode,
    'createdAt': DateTime.now().toIso8601String(),
  };

  factory Group.fromMap(String id, Map<String, dynamic> m) => Group(
    id: id,
    name: (m['name'] ?? '') as String,
    createdBy: (m['createdBy'] ?? '') as String,
    membersCount: (m['membersCount'] ?? 1) as int,
    requireApproval: (m['requireApproval'] ?? true) as bool,
    adminBypass: (m['adminBypass'] ?? true) as bool,
    approvalMode: (m['approvalMode'] ?? 'any') as String,
  );
}
