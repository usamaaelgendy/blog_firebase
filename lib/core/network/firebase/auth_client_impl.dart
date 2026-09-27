import 'dart:async';

import 'package:blog_app/core/error/exceptions.dart';
import 'package:blog_app/core/network/auth_client.dart';
import 'package:blog_app/features/auth/data/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class FirebaseAuthClient implements AuthClient {
  final fb.FirebaseAuth _firebaseAuth;

  /// Set by [signInWithOtp] and consumed by [verifyOtp].
  String? _phoneVerificationId;

  FirebaseAuthClient(this._firebaseAuth);

  @override
  Future<UserModel> signUp({required String email, required String password, required String name}) {
    return _guard(() async {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
      final user = _requireUser(credential.user, 'Signup failed: no user returned');
      await user.updateDisplayName(name);
      await user.sendEmailVerification();
      await user.reload();
      return UserModel.fromFirebaseUser(_firebaseAuth.currentUser ?? user);
    });
  }

  @override
  Future<UserModel> signIn({required String email, required String password}) {
    return _guard(() async {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
      return UserModel.fromFirebaseUser(_requireUser(credential.user, 'Login failed: no user returned'));
    });
  }

  @override
  Future<void> resetPasswordForEmail({required String email}) {
    return _guard(() => _firebaseAuth.sendPasswordResetEmail(email: email));
  }

  @override
  Future<UserModel> verifyPasswordResetOtp({required String email, required String otp}) {
    // Firebase resets passwords through an emailed link, not an OTP that signs the user in.
    throw AuthException('Password reset via OTP is not supported by Firebase', 'unsupported');
  }

  @override
  Future<void> updatePassword({required String password}) {
    return _guard(() => _requireUser(_firebaseAuth.currentUser, 'User not authenticated').updatePassword(password));
  }

  @override
  Future<UserModel> signInWithIdToken(SocialProvider provider, String idToken) {
    return _guard(() async {
      final fb.AuthCredential credential;
      switch (provider) {
        case SocialProvider.google:
          credential = fb.GoogleAuthProvider.credential(idToken: idToken);
        case SocialProvider.apple:
          credential = fb.OAuthProvider('apple.com').credential(idToken: idToken);
        case SocialProvider.github:
          throw AuthException('GitHub does not support ID token sign-in', 'unsupported');
      }
      final result = await _firebaseAuth.signInWithCredential(credential);
      return UserModel.fromFirebaseUser(_requireUser(result.user, 'Failed to sign in with ${provider.name}'));
    });
  }

  @override
  Future<bool> signInWithOAuth(SocialProvider provider, String callbackUrl) {
    // Firebase handles the redirect itself, so [callbackUrl] is not used.
    return _guard(() async {
      final fb.AuthProvider authProvider;
      switch (provider) {
        case SocialProvider.google:
          authProvider = fb.GoogleAuthProvider();
        case SocialProvider.apple:
          authProvider = fb.AppleAuthProvider();
        case SocialProvider.github:
          authProvider = fb.GithubAuthProvider();
      }
      final result = await _firebaseAuth.signInWithProvider(authProvider);
      return result.user != null;
    });
  }

  @override
  Future<void> signInWithOtp({required String phoneNumber}) {
    return _guard(() {
      final completer = Completer<void>();
      _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) async {
          // Android auto-retrieval: sign in straight away.
          await _firebaseAuth.signInWithCredential(credential);
          if (!completer.isCompleted) completer.complete();
        },
        verificationFailed: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        codeSent: (verificationId, _) {
          _phoneVerificationId = verificationId;
          if (!completer.isCompleted) completer.complete();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _phoneVerificationId = verificationId;
        },
      );
      return completer.future;
    });
  }

  @override
  Future<UserModel> verifyOtp({required String phoneNumber, required String otp}) {
    return _guard(() async {
      final verificationId = _phoneVerificationId;
      if (verificationId == null) throw AuthException('Request an OTP before verifying it');
      final credential = fb.PhoneAuthProvider.credential(verificationId: verificationId, smsCode: otp);
      final result = await _firebaseAuth.signInWithCredential(credential);
      _phoneVerificationId = null;
      return UserModel.fromFirebaseUser(_requireUser(result.user, 'OTP verification failed'));
    });
  }

  @override
  UserModel? get currentUser {
    final user = _firebaseAuth.currentUser;
    return user == null ? null : UserModel.fromFirebaseUser(user);
  }

  @override
  Future<void> signOut() {
    return _guard(() => _firebaseAuth.signOut());
  }

  @override
  Stream<UserModel?> get onAuthStateChange =>
      _firebaseAuth.authStateChanges().map((user) => user == null ? null : UserModel.fromFirebaseUser(user));

  @override
  Future<UserModel> updateUser({String? name, String? avatarUrl}) {
    return _guard(() async {
      final user = _requireUser(_firebaseAuth.currentUser, 'User not authenticated');
      if (name != null) await user.updateDisplayName(name);
      if (avatarUrl != null) await user.updatePhotoURL(avatarUrl);
      await user.reload();
      return UserModel.fromFirebaseUser(_firebaseAuth.currentUser ?? user);
    });
  }

  @override
  Future<void> deleteAccount() {
    return _guard(() => _requireUser(_firebaseAuth.currentUser, 'User not authenticated').delete());
  }

  fb.User _requireUser(fb.User? user, String message) {
    if (user == null) throw AuthException(message);
    return user;
  }

  /// Converts Firebase auth errors into the app's [AuthException].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Authentication failed', e.code);
    }
  }
}
