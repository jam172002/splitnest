class AppUser {
  final String uid;
  final String email;

  AppUser({required this.uid, required this.email});

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
  };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
    uid: (m['uid'] ?? '') as String,
    email: (m['email'] ?? '') as String,
  );
}
