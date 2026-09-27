import 'package:blog_app/core/error/exceptions.dart';
import 'package:blog_app/core/network/auth_client.dart';
import 'package:blog_app/features/auth/data/datasources/session_datasource.dart';
import 'package:blog_app/features/auth/data/models/user_model.dart';

class SessionDataSourceImpl implements SessionDataSource {
  final AuthClient _authClient;

  SessionDataSourceImpl(this._authClient);

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      return _authClient.currentUser;
    } catch (e) {
      throw ServerException('Failed to get current user: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _authClient.signOut();
    } catch (e) {
      throw ServerException('Failed to sign out: ${e.toString()}');
    }
  }

  @override
  Stream<UserModel?> get authStateChanges => _authClient.onAuthStateChange;
}
