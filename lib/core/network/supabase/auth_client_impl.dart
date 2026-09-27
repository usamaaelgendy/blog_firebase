import 'package:blog_app/core/error/exceptions.dart';
import 'package:blog_app/core/network/auth_client.dart';
import 'package:blog_app/features/auth/data/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class SupabaseAuthClient implements AuthClient {
  final sb.GoTrueClient _client;
  final sb.FunctionsClient _functions;

  SupabaseAuthClient(this._client, this._functions);

  @override
  Future<UserModel> signUp({required String email, required String password, required String name}) {
    return _guard(() async {
      final response = await _client.signUp(email: email, password: password, data: {'name': name});
      return _requireUser(response.user, 'Signup failed: no user returned');
    });
  }

  @override
  Future<UserModel> signIn({required String email, required String password}) {
    return _guard(() async {
      final response = await _client.signInWithPassword(email: email, password: password);
      return _requireUser(response.user, 'Login failed: no user returned');
    });
  }

  @override
  Future<void> resetPasswordForEmail({required String email}) {
    return _guard(() => _client.resetPasswordForEmail(email));
  }

  @override
  Future<UserModel> verifyPasswordResetOtp({required String email, required String otp}) {
    return _guard(() async {
      final response = await _client.verifyOTP(email: email, token: otp, type: sb.OtpType.recovery);
      return _requireUser(response.user, 'OTP verification failed');
    });
  }

  @override
  Future<void> updatePassword({required String password}) {
    return _guard(() => _client.updateUser(sb.UserAttributes(password: password)));
  }

  @override
  Future<UserModel> signInWithIdToken(SocialProvider provider, String idToken) {
    return _guard(() async {
      final response = await _client.signInWithIdToken(provider: _mapProvider(provider), idToken: idToken);
      return _requireUser(response.user, 'Failed to sign in with ${provider.name}');
    });
  }

  @override
  Future<bool> signInWithOAuth(SocialProvider provider, String callbackUrl) {
    return _guard(
      () => _client.signInWithOAuth(
        _mapProvider(provider),
        redirectTo: callbackUrl,
        authScreenLaunchMode: sb.LaunchMode.externalApplication,
      ),
    );
  }

  @override
  Future<void> signInWithOtp({required String phoneNumber}) {
    return _guard(() => _client.signInWithOtp(phone: phoneNumber));
  }

  @override
  Future<UserModel> verifyOtp({required String phoneNumber, required String otp}) {
    return _guard(() async {
      final response = await _client.verifyOTP(phone: phoneNumber, token: otp, type: sb.OtpType.sms);
      return _requireUser(response.user, 'OTP verification failed');
    });
  }

  @override
  UserModel? get currentUser {
    final user = _client.currentUser;
    return user == null ? null : UserModel.fromSupabaseUser(user);
  }

  @override
  Future<void> signOut() {
    return _guard(() => _client.signOut(scope: sb.SignOutScope.global));
  }

  @override
  Stream<UserModel?> get onAuthStateChange => _client.onAuthStateChange.map((authState) {
        final user = authState.session?.user;
        return user == null ? null : UserModel.fromSupabaseUser(user);
      });

  @override
  Future<UserModel> updateUser({String? name, String? avatarUrl}) {
    return _guard(() async {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (avatarUrl != null) data['avatar_url'] = avatarUrl;
      final response = await _client.updateUser(sb.UserAttributes(data: data));
      return _requireUser(response.user, 'Failed to update profile');
    });
  }

  @override
  Future<void> deleteAccount() {
    return _guard(() async {
      final response = await _functions.invoke('delete-account');
      await _client.signOut(scope: sb.SignOutScope.global);

      if (response.status != 200) {
        throw AuthException('Failed to delete account');
      }
    });
  }

  sb.OAuthProvider _mapProvider(SocialProvider provider) {
    switch (provider) {
      case SocialProvider.google:
        return sb.OAuthProvider.google;
      case SocialProvider.apple:
        return sb.OAuthProvider.apple;
      case SocialProvider.github:
        return sb.OAuthProvider.github;
    }
  }

  UserModel _requireUser(sb.User? user, String message) {
    if (user == null) throw AuthException(message);
    return UserModel.fromSupabaseUser(user);
  }

  /// Converts Supabase auth errors into the app's [AuthException].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on sb.AuthException catch (e) {
      throw AuthException(e.message, e.code);
    }
  }
}
