class FirestorePaths {
  static const users = 'users';
  static const groups = 'groups';

  static String groupMembers(String groupId) => 'groups/$groupId/members';
  static String groupTx(String groupId) => 'groups/$groupId/tx';
  static String groupCategories(String groupId) => 'groups/$groupId/categories';

  static String personalTx(String uid) => 'users/$uid/personalTx';
}
