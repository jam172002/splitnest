
class Group {
  final String id;
  final String name;
  final String createdBy;

  /// NEW: Actual list of member IDs for filtering and counting
  final List<String> memberUids;

  /// number of members in this group
  final int membersCount;

  /// require approval for member entries
  final bool requireApproval;

  /// admin entries auto approved
  final bool adminBypass;

  /// "any" | "all" | "admin_only"
  final String approvalMode;
  /// 'simple' or 'business'
  final String type;

  Group({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.memberUids, // Required for list updates
    this.membersCount = 1,
    this.requireApproval = true,
    this.adminBypass = true,
    this.approvalMode = 'any',
    this.type = 'simple',
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'createdBy': createdBy,
    'memberUids': memberUids, // Keep this synced in Firestore
    'membersCount': membersCount,
    'requireApproval': requireApproval,
    'adminBypass': adminBypass,
    'approvalMode': approvalMode,
    'type': type,
    'createdAt': DateTime.now().toIso8601String(),
  };

  factory Group.fromMap(String id, Map<String, dynamic> m) => Group(
    id: id,
    name: (m['name'] ?? '') as String,
    createdBy: (m['createdBy'] ?? '') as String,
    // Safely parse the memberUids list from Firestore
    memberUids: List<String>.from(m['memberUids'] ?? []),
    membersCount: (m['membersCount'] ?? 1) as int,
    requireApproval: (m['requireApproval'] ?? true) as bool,
    adminBypass: (m['adminBypass'] ?? true) as bool,
    approvalMode: (m['approvalMode'] ?? 'any') as String,
    type: (m['type'] ?? 'simple') as String,
  );
}