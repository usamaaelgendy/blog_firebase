import 'package:blog_app/features/auth/data/models/user_model.dart';

/// Backend-agnostic social providers, mapped to each SDK's own type by the implementations.
enum SocialProvider { google, apple, github }

/// Implementations must return [UserModel] and throw the app's `AuthException`
/// (from `core/error/exceptions.dart`) so datasources never depend on a specific SDK.
abstract class AuthClient {
  Future<UserModel> signUp({required String email, required String password, required String name});

  Future<UserModel> signIn({required String email, required String password});

  Future<void> resetPasswordForEmail({required String email});

  Future<UserModel> verifyPasswordResetOtp({required String email, required String otp});

  Future<void> updatePassword({required String password});

  Future<UserModel> signInWithIdToken(SocialProvider provider, String idToken);

  Future<bool> signInWithOAuth(SocialProvider provider, String callbackUrl);

  Future<void> signInWithOtp({required String phoneNumber});

  Future<UserModel> verifyOtp({required String phoneNumber, required String otp});

  UserModel? get currentUser;

  Future<void> signOut();

  Stream<UserModel?> get onAuthStateChange;

  Future<UserModel> updateUser({String? name, String? avatarUrl});

  Future<void> deleteAccount();
}
