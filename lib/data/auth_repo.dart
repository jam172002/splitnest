import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class AuthRepo extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSubscription;

  AuthRepo() {
    // Listen to Firebase and notify the Router whenever the user changes
    _authSubscription = _auth.authStateChanges().listen((user) {
      notifyListeners();
    });
  }

  User? get currentUser => _auth.currentUser;

  Future<void> register(String name, String email, String pass) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: pass,
    );
    await credential.user?.updateDisplayName(name);
    await _db.collection('users').doc(credential.user!.uid).set({
      'name': name,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> login(String email, String pass) async {
    await _auth.signInWithEmailAndPassword(email: email, password: pass);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
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
