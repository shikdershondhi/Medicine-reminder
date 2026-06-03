import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../shared/models.dart';
import 'database_service.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class AuthService {
  static bool isFirebaseInitialized = false;
  
  late final GoogleSignIn _googleSignIn;
  final DatabaseService _dbService = DatabaseService();

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  
  AuthService._internal() {
    _googleSignIn = GoogleSignIn.instance;
  }

  Future<void> init() async {
    await _googleSignIn.initialize();
  }

  // Abstracted Stream representing authentication changes
  Stream<User?> get authStateChanges {
    if (isFirebaseInitialized) {
      return FirebaseAuth.instance.authStateChanges();
    } else {
      // Mock stream based on local settings box login state
      final box = Hive.box('settings');
      return box.watch(key: 'mock_logged_in').map((event) {
        final isLoggedIn = event.value == true;
        final email = box.get('current_user_email', defaultValue: 'alex.johnson@gmail.com') as String;
        return isLoggedIn ? MockUser(email: email) : null;
      });
    }
  }

  User? get currentUser {
    if (isFirebaseInitialized) {
      return FirebaseAuth.instance.currentUser;
    } else {
      final box = Hive.box('settings');
      final isLoggedIn = box.get('mock_logged_in', defaultValue: false) == true;
      final email = box.get('current_user_email', defaultValue: 'alex.johnson@gmail.com') as String;
      return isLoggedIn ? MockUser(email: email) : null;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (isFirebaseInitialized) {
      try {
        final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        final clientAuth = await googleUser.authorizationClient.authorizeScopes([
          'email',
          'https://www.googleapis.com/auth/drive.file',
        ]);
        
        final credential = GoogleAuthProvider.credential(
          accessToken: clientAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        return await FirebaseAuth.instance.signInWithCredential(credential);
      } catch (e) {
        print("Google Sign In Error: $e");
        rethrow;
      }
    } else {
      // Simulating local mockup sign in
      print("Bypassing Firebase Auth. Performing local mock sign-in...");
      await Future.delayed(const Duration(milliseconds: 800));
      
      final box = Hive.box('settings');
      await box.put('mock_logged_in', true);
      
      // Auto pre-populate a default profile name if empty
      final currentProfile = _dbService.getProfile();
      if (currentProfile.name.isEmpty) {
        await _dbService.saveProfile(UserProfile(
          name: 'Alex Johnson',
          sex: 'Male',
          weight: 72.5,
          age: 34,
        ));
      }
      
      return MockUserCredential();
    }
  }

  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    if (isFirebaseInitialized) {
      try {
        return await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      } catch (e) {
        print("Firebase Sign In Error: $e");
        rethrow;
      }
    } else {
      final dbPassword = _dbService.getAccountPassword(email);
      if (dbPassword == null) {
        throw Exception("Account not found.");
      }
      if (dbPassword != password) {
        throw Exception("Incorrect password.");
      }
      
      final box = Hive.box('settings');
      await box.put('mock_logged_in', true);
      await box.put('current_user_email', email.trim());
      
      // Auto pre-populate a default profile name if empty
      final currentProfile = _dbService.getProfile();
      if (currentProfile.name.isEmpty) {
        await _dbService.saveProfile(UserProfile(
          name: email.split('@').first,
          sex: 'Male',
          weight: 70.0,
          age: 30,
        ));
      }
      return MockUserCredential();
    }
  }

  Future<UserCredential?> signUpWithEmailAndPassword(String email, String password) async {
    if (isFirebaseInitialized) {
      try {
        return await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      } catch (e) {
        print("Firebase Sign Up Error: $e");
        rethrow;
      }
    } else {
      if (_dbService.hasAccount(email)) {
        throw Exception("Account already exists with this email.");
      }
      await _dbService.saveAccount(email, password);
      
      final box = Hive.box('settings');
      await box.put('mock_logged_in', true);
      await box.put('current_user_email', email.trim());
      
      await _dbService.saveProfile(UserProfile(
        name: email.split('@').first,
        sex: 'Male',
        weight: 70.0,
        age: 30,
      ));
      
      return MockUserCredential();
    }
  }

  Future<void> signOut() async {
    try {
      if (isFirebaseInitialized) {
        await FirebaseAuth.instance.signOut();
      } else {
        final box = Hive.box('settings');
        await box.put('mock_logged_in', false);
      }
      await _googleSignIn.signOut();
    } catch (e) {
      print("Sign Out Error: $e");
    }
  }

  Future<http.Client?> getAuthenticatedClient() async {
    try {
      final googleUser = await _googleSignIn.attemptLightweightAuthentication();
      if (googleUser == null) return null;
      
      final authorization = await googleUser.authorizationClient.authorizationForScopes([
        'https://www.googleapis.com/auth/drive.file'
      ]);
      
      final token = authorization?.accessToken;
      if (token == null) return null;

      final authHeaders = {
        'Authorization': 'Bearer $token',
        'X-Goog-AuthUser': '0',
      };
      return GoogleAuthClient(authHeaders);
    } catch (e) {
      print("Error getting authenticated client: $e");
      return null;
    }
  }
  
  Future<bool> hasDrivePermission() async {
    try {
      final googleUser = await _googleSignIn.attemptLightweightAuthentication();
      if (googleUser == null) return false;
      final authorization = await googleUser.authorizationClient.authorizationForScopes([
        'https://www.googleapis.com/auth/drive.file'
      ]);
      return authorization != null;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> requestDrivePermission() async {
    try {
      final googleUser = await _googleSignIn.attemptLightweightAuthentication();
      if (googleUser == null) return false;
      final authorization = await googleUser.authorizationClient.authorizeScopes([
        'https://www.googleapis.com/auth/drive.file'
      ]);
      return authorization.accessToken != null;
    } catch (e) {
      return false;
    }
  }
}

// Mock User matching the Firebase User interface
class MockUser implements User {
  final String _email;
  MockUser({String email = 'alex.johnson@gmail.com'}) : _email = email;

  @override
  String get email => _email;
  
  @override
  String get displayName => _email.split('@').first;

  @override
  String get uid => 'mock_user_12345';

  @override
  bool get emailVerified => true;

  @override
  bool get isAnonymous => false;

  @override
  String? get photoURL => 'https://lh3.googleusercontent.com/aida-public/placeholder';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Mock UserCredential matching Firebase UserCredential interface
class MockUserCredential implements UserCredential {
  @override
  User get user => MockUser();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
