import 'package:firebase_auth/firebase_auth.dart';

class AuthRepo {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> authChanges() => _auth.authStateChanges();

  Future<void> register(String email, String pass) async {
    await _auth.createUserWithEmailAndPassword(email: email, password: pass);
  }

  Future<void> login(String email, String pass) async {
    await _auth.signInWithEmailAndPassword(email: email, password: pass);
  }

  Future<void> logout() => _auth.signOut();
}
