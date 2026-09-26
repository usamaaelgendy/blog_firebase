import 'package:blog_app/core/network/firebase/auth_client.dart';
import 'package:blog_app/features/auth/data/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthClientImpl implements AuthClient {
  final FirebaseAuth _firebaseAuth;

  AuthClientImpl(this._firebaseAuth);

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(name);
    await credential.user?.sendEmailVerification();
    await credential.user?.reload();

    return UserModel.fromFirebaseUser(_firebaseAuth.currentUser!);
  }

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return UserModel.fromFirebaseUser(credential.user!);
  }

  @override
  Future<void> resetPasswordForEmail({required String email}) async {}

  @override
  Future<UserModel> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<UserModel> updatePassword({required String password}) async {
    throw UnimplementedError();
  }

  @override
  UserModel? get getCurrentUser =>
      UserModel.fromFirebaseUser(_firebaseAuth.currentUser!);

  @override
  UserModel? get currentUser =>
      UserModel.fromFirebaseUser(_firebaseAuth.currentUser!);

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  @override
  Stream<UserModel> get onAuthStateChange => _firebaseAuth
      .authStateChanges()
      .map((user) => UserModel.fromFirebaseUser(user!));

  @override
  Future<UserModel> updateUser({String? name, String? avatarUrl}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteAccount() async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteUser(String userId) async {
    await deleteAccount();
  }
}
