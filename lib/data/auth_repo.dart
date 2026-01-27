import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class AuthRepo extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _authSubscription;

  AuthRepo() {
    // Listen to Firebase and notify the Router whenever the user changes
    _authSubscription = _auth.authStateChanges().listen((user) {
      notifyListeners();
    });
  }

  User? get currentUser => _auth.currentUser;

  Future<void> register(String email, String pass) async {
    await _auth.createUserWithEmailAndPassword(email: email, password: pass);
  }

  Future<void> login(String email, String pass) async {
    await _auth.signInWithEmailAndPassword(email: email, password: pass);
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}