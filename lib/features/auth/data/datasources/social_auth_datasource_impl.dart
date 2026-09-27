import 'package:blog_app/core/error/exceptions.dart';
import 'package:blog_app/core/network/auth_client.dart';
import 'package:blog_app/features/auth/data/datasources/social_auth_datasource.dart';
import 'package:blog_app/features/auth/data/models/user_model.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SocialAuthDataSourceImpl implements SocialAuthDataSource {
  final AuthClient _authClient;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isInitialized = false;

  SocialAuthDataSourceImpl(this._authClient);

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    const serverClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    await _googleSignIn.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    _isInitialized = true;
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      await _ensureInitialized();
      final googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;

      if (idToken == null) {
        throw ServerException('Failed to get Google ID token');
      }

      return await _authClient.signInWithIdToken(SocialProvider.google, idToken);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to sign in with Google: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> signInWithApple() async {
    try {
      throw UnimplementedError('Apple sign-in not configured for this project');
    } on AuthException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to sign in with Apple: ${e.toString()}');
    }
  }

  @override
  Future<void> signInWithGitHub() async {
    try {
      await _authClient.signInWithOAuth(
        SocialProvider.github,
        'com.elgendy.authflowapp://login-callback',
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to sign in with GitHub: ${e.toString()}');
    }
  }
}
