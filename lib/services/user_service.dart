import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import './firebase_service.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  static final CollectionReference _usersCollection = _firestore.collection(
    'users',
  );
  static final CollectionReference _customersCollection = _firestore.collection('customers');
  static final CollectionReference _bloggersCollection = _firestore.collection('bloggers');
  static final CollectionReference _restaurantsCollection = _firestore.collection('restaurants');
  static const List<String> _allowedRolesForThisApp = ['customer', 'blogger'];

  static int _appIdForRole(String role) {
    switch (role) {
      case 'customer':
        return 1;
      case 'blogger':
        return 2;
      case 'restaurant':
        return 3;
      default:
        return 1;
    }
  }

  // Add rate limiting variables
  static DateTime? _lastUpdateTime;
  static const _minimumUpdateInterval = Duration(seconds: 2);

  static Future<void> initializeUserCollection() async {
    try {
      final collectionExists = await FirebaseService.verifyCollection('users');
      if (!collectionExists) {
        await FirebaseService.initialize();
      }
    } catch (e) {
      print('Error initializing user collection: $e');
      rethrow;
    }
  }

  static Future<DocumentSnapshot> getUserData(String userId) async {
    try {
      await initializeUserCollection();
      final doc = await _usersCollection.doc(userId).get();
      print('Retrieved user data for: $userId');
      return doc;
    } catch (e) {
      print('Error getting user data: $e');
      rethrow;
    }
  }

  static Future<bool> isUsernameAvailable(String username) async {
    try {
      await initializeUserCollection();
      final QuerySnapshot result =
          await _firestore
              .collection('users')
              .where('username', isEqualTo: username)
              .limit(1)
              .get();
      return result.docs.isEmpty;
    } catch (e) {
      print('Error checking username availability: $e');
      rethrow;
    }
  }

  static Future<void> createUser(UserModel user) async {
    try {
      await initializeUserCollection();
      await _usersCollection.doc(user.id).set(user.toMap());
      print('User created successfully: ${user.email}');
    } catch (e) {
      print('Error creating user: $e');
      if (e.toString().contains('permission-denied')) {
        throw Exception('Permission denied. Please check your Firestore security rules.');
      } else if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        rethrow;
      }
    }
  }

  // Initialize role-specific defaults and denormalized collections
  static Future<void> _initializeDefaultsForRole({
    required String userId,
    required String role,
    required String name,
    required String email,
    String? username,
    String? phoneNumber,
  }) async {
    try {
      if (role == 'customer') {
        // customers collection: behavior and history counters
        await _customersCollection.doc(userId).set({
          'id': userId,
          'name': name,
          'email': email,
          'username': username ?? email.split('@').first,
          'phoneNumber': phoneNumber,
          'createdAt': FieldValue.serverTimestamp(),
          'history': {
            'pending': 0,
            'past': 0,
            'cancelled': 0,
            'items': [],
          },
          'behavior': {
            'searches': 0,
            'views': 0,
            'favourites': 0,
            'lastActiveAt': FieldValue.serverTimestamp(),
          },
        }, SetOptions(merge: true));
      } else if (role == 'blogger') {
        // bloggers collection: analytics and content counters
        await _bloggersCollection.doc(userId).set({
          'id': userId,
          'name': name,
          'email': email,
          'username': username ?? email.split('@').first,
          'createdAt': FieldValue.serverTimestamp(),
          'stats': {
            'totalReels': 0,
            'totalPosts': 0,
            'totalViews': 0,
            'followers': 0,
            'likes': 0,
            'comments': 0,
          },
          'performance': {
            'graphPoints': [],
            'audienceInsights': {
              'topLocations': [],
            },
            'topPosts': [],
          },
        }, SetOptions(merge: true));
      } else if (role == 'restaurant') {
        // restaurants collection: base profile and zeroed analytics
        await _restaurantsCollection.doc(userId).set({
          'id': userId,
          'ownerUserId': userId,
          'name': name,
          'email': email,
          'phoneNumber': phoneNumber,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'image': '',
          'cuisine': '',
          'address': '',
          'fullAddress': '',
          'tags': [],
          'menu': {},
          'rating': 0.0,
          'deliveryTime': '',
          'distance': '0 km',
          'featured': false,
          'popular': false,
          'analytics': {
            'orders': 0,
            'revenue': 0.0,
            'tableBookings': 0,
            'returningCustomers': 0,
          },
          'visibility': 'public',
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error initializing defaults for role $role: $e');
    }
  }

  static Future<void> updateUser(UserModel user) async {
    try {
      // Check if enough time has passed since last update
      if (_lastUpdateTime != null) {
        final timeSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!);
        if (timeSinceLastUpdate < _minimumUpdateInterval) {
          // Wait for the remaining time
          await Future.delayed(_minimumUpdateInterval - timeSinceLastUpdate);
        }
      }

      await initializeUserCollection();
      await _usersCollection.doc(user.id).update(user.toMap());

      // Update the last update time
      _lastUpdateTime = DateTime.now();

      print('User updated successfully: ${user.id}');
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  static Future<void> deleteUser(String userId) async {
    try {
      await initializeUserCollection();
      await _usersCollection.doc(userId).delete();
      print('User deleted successfully: $userId');
    } catch (e) {
      print('Error deleting user: $e');
      rethrow;
    }
  }

  static Future<bool> userExists(String userId) async {
    final doc = await _usersCollection.doc(userId).get();
    return doc.exists;
  }

  static Future<UserModel?> getUserModel(String userId) async {
    final doc = await _usersCollection.doc(userId).get();
    if (!doc.exists) return null;

    return UserModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  static Future<GoogleSignInAccount?> getGoogleUser() async {
    try {
      print('Starting Google sign-in flow...');

      // Check if there's a previously signed-in user and sign out
      try {
        if (_googleSignIn.currentUser != null) {
          await _googleSignIn.signOut();
          print('Signed out previous Google user');
        }
      } catch (e) {
        print('Error signing out previous user: $e');
        // Continue even if sign out fails
      }

      // Trigger the authentication flow
      print('Prompting user for Google sign-in...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('Google sign-in was cancelled by user');
      } else {
        print('Google sign-in successful: ${googleUser.email}');
      }

      return googleUser;
    } catch (e) {
      print('Error getting Google user: $e');
      print('Error details: ${e.runtimeType}');
      return null;
    }
  }

  static Future<UserCredential> signInWithGoogle({required String role}) async {
    try {
      print('Starting Google sign-in process...');

      // First make sure we're signed out from Firebase
      try {
        await _auth.signOut();
      } catch (e) {
        print('Error signing out from Firebase: $e');
        // Continue even if sign out fails
      }

      // Get the Google user with our helper method
      final GoogleSignInAccount? googleUser = await getGoogleUser();

      if (googleUser == null) {
        print('Google sign-in was cancelled by user');
        throw FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER',
          message: 'Sign in aborted by user',
        );
      }

      try {
        print('Getting Google auth details for ${googleUser.email}');

        // Get authentication details
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        print('Access Token: ${googleAuth.accessToken?.substring(0, 10)}...');
        print('ID Token: ${googleAuth.idToken?.substring(0, 10)}...');

        if (googleAuth.accessToken == null || googleAuth.idToken == null) {
          print('Failed to get Google auth tokens');
          throw FirebaseAuthException(
            code: 'invalid-credential',
            message: 'Unable to obtain Google authentication tokens',
          );
        }

        print('Creating Firebase credential with Google tokens');
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        print('Signing in to Firebase with Google credential');
        final userCredential = await _auth.signInWithCredential(credential);

        if (userCredential.user == null) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'Failed to get user after successful authentication',
          );
        }

        print('Firebase sign-in successful: ${userCredential.user?.email}');

        // Create or update user document
        try {
          final user = userCredential.user;
          if (user == null) {
            throw Exception('User credential is null');
          }

          final userDoc = await _usersCollection.doc(user.uid).get();

          if (!userDoc.exists) {
            print('Creating new user document for Google user');
            // Enforce allowed roles in this app for new users
            final String enforcedRole = _allowedRolesForThisApp.contains(role) ? role : 'customer';
            final int enforcedAppId = _appIdForRole(enforcedRole);
            final newUser = UserModel(
              id: user.uid,
              email: user.email ?? '',
              name: user.displayName ?? (user.email?.split('@')[0] ?? 'User'),
              username: user.email?.split('@')[0] ?? 'user',
              phoneNumber: user.phoneNumber,
              profileImageUrl: user.photoURL,
              createdAt: DateTime.now(),
              lastLoginAt: DateTime.now(),
              isEmailVerified: user.emailVerified,
              metadata: {
                'lastPasswordChange': DateTime.now().toIso8601String(),
                'createdBy': 'google',
                'accountType': 'google.com',
                'role': enforcedRole,
                'appId': enforcedAppId,
                'createdAt': DateTime.now().toIso8601String(),
              },
            );

            await createUser(newUser);
          } else {
            print('Updating existing user document for Google user');
            // Read existing role and enforce access
            final Map<String, dynamic> existingData = userDoc.data() as Map<String, dynamic>;
            String? existingRole;
            if (existingData['metadata'] != null && existingData['metadata'] is Map) {
	          existingRole = (existingData['metadata'] as Map<String, dynamic>)['role'] as String?;
	        }
            if (existingRole == null && existingData.containsKey('role')) {
              existingRole = existingData['role'] as String?;
            }
            int? existingAppId;
            if (existingData['metadata'] != null && existingData['metadata'] is Map) {
              existingAppId = (existingData['metadata'] as Map<String, dynamic>)['appId'] as int?;
            }

            if (existingRole != null && !_allowedRolesForThisApp.contains(existingRole)) {
              // Disallow login for roles outside this app (e.g., restaurant)
              await _auth.signOut();
              throw FirebaseAuthException(code: 'role-not-allowed', message: 'This account role is not permitted in this app.');
            }

            final Map<String, dynamic> updateMap = {
              'lastLoginAt': FieldValue.serverTimestamp(),
              'isEmailVerified': user.emailVerified,
              'profileImageUrl': user.photoURL,
              'name': user.displayName,
              'metadata.lastLoginAt': FieldValue.serverTimestamp(),
            };
            // Only set appId if missing
            if (existingAppId == null) {
              final String roleToMap = existingRole ?? (_allowedRolesForThisApp.contains(role) ? role : 'customer');
              updateMap['metadata.appId'] = _appIdForRole(roleToMap);
            }

            await _usersCollection.doc(user.uid).update(updateMap);
          }
        } catch (e) {
          // If we fail to update the user document, log but continue
          print('Error updating user document: $e');
          print('User was authenticated but document update failed');
        }

        return userCredential;
      } catch (e) {
        print('Error during Google authentication: $e');
        print('Error type: ${e.runtimeType}');
        rethrow;
      }
    } catch (e) {
      print('Error in Google sign-in process: $e');
      print('Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      print('Attempting to sign in user: $email with role: $role');
      
      // Sign in with email and password
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found with this email',
        );
      }

      print('Firebase Auth successful, checking Firestore document...');

      // Check if user document exists
      final user = userCredential.user!;
      final userDoc = await _usersCollection.doc(user.uid).get();

      if (!userDoc.exists) {
        print('User document does not exist, creating new one...');
        // Create new user document if it doesn't exist
        // Enforce allowed roles in this app for new users
        final String enforcedRole = _allowedRolesForThisApp.contains(role) ? role : 'customer';
        final int enforcedAppId = _appIdForRole(enforcedRole);
        final newUser = UserModel(
          id: user.uid,
          email: user.email ?? email,
          name: user.displayName ?? email.split('@')[0],
          username: email.split('@')[0],
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          isEmailVerified: user.emailVerified,
          metadata: {
            'createdBy': 'email',
            'accountType': 'email',
            'role': enforcedRole,
            'appId': enforcedAppId,
            'createdAt': DateTime.now().toIso8601String(),
          },
        );

        await createUser(newUser);
        await _initializeDefaultsForRole(
          userId: user.uid,
          role: enforcedRole,
          name: newUser.name,
          email: newUser.email,
          username: newUser.username,
        );
        print('New user document created successfully');
      } else {
        print('User document exists, updating last login...');
        // Check existing role and block if not allowed in this app
        final Map<String, dynamic> existingData = userDoc.data() as Map<String, dynamic>;
        String? existingRole;
        if (existingData['metadata'] != null && existingData['metadata'] is Map) {
          existingRole = (existingData['metadata'] as Map<String, dynamic>)['role'] as String?;
        }
        if (existingRole == null && existingData.containsKey('role')) {
          existingRole = existingData['role'] as String?;
        }
        int? existingAppId;
        if (existingData['metadata'] != null && existingData['metadata'] is Map) {
          existingAppId = (existingData['metadata'] as Map<String, dynamic>)['appId'] as int?;
        }

        if (existingRole != null && !_allowedRolesForThisApp.contains(existingRole)) {
          await _auth.signOut();
          throw FirebaseAuthException(code: 'role-not-allowed', message: 'This account role is not permitted in this app.');
        }

        // Update last login time without changing role; set appId only if missing
        final Map<String, dynamic> updateMap = {
          'lastLoginAt': FieldValue.serverTimestamp(),
          'metadata.lastLoginAt': FieldValue.serverTimestamp(),
        };
        if (existingAppId == null) {
          final String roleToMap = existingRole ?? (_allowedRolesForThisApp.contains(role) ? role : 'customer');
          updateMap['metadata.appId'] = _appIdForRole(roleToMap);
        }
        await _usersCollection.doc(user.uid).update(updateMap);
        print('User document updated successfully');
      }

      print('Sign in completed successfully');
      return userCredential;
    } catch (e) {
      print('Error signing in user: $e');
      print('Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  static Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String username,
    String? phoneNumber,
    required String role,
  }) async {
    UserCredential? userCredential;
    try {
      print('Attempting to sign up user: $email with role: $role');
      
      // Create user in Firebase Auth
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw FirebaseAuthException(
          code: 'user-creation-failed',
          message: 'Failed to create user account',
        );
      }

      print('Firebase Auth user created, creating Firestore document...');

      // Create user in Firestore
      final int enforcedAppId = _appIdForRole(role);
      final user = UserModel(
        id: userCredential.user!.uid,
        email: email,
        name: name,
        username: username,
        phoneNumber: phoneNumber,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        isEmailVerified: userCredential.user!.emailVerified,
        metadata: {
          'createdBy': 'email',
          'accountType': 'email',
          'role': role,
          'appId': enforcedAppId,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      await createUser(user);
      print('User document created, initializing role defaults...');
      
      await _initializeDefaultsForRole(
        userId: user.id,
        role: role,
        name: name,
        email: email,
        username: username,
        phoneNumber: phoneNumber,
      );
      
      print('Sign up completed successfully');
      return userCredential;
    } catch (e) {
      print('Error signing up user: $e');
      print('Error type: ${e.runtimeType}');
      // If Firestore creation fails, clean up Firebase Auth user
      if (userCredential?.user != null) {
        try {
          print('Cleaning up Firebase Auth user due to error...');
          await userCredential!.user!.delete();
        } catch (deleteError) {
          print('Error cleaning up user: $deleteError');
        }
      }
      rethrow;
    }
  }

  // Check if email is already used with a specific role
  static Future<bool> isEmailUsedWithRole(String email, String role) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('users')
              .where('email', isEqualTo: email)
              .get();

      if (querySnapshot.docs.isEmpty) {
        return false; // Email doesn't exist yet
      }

      // If user exists, check their role
      for (var doc in querySnapshot.docs) {
        final userData = doc.data();
        final existingRole = userData['metadata']?['role'] as String?;
        final roles = userData['metadata']?['roles'] as List<dynamic>?;

        // If role matches exactly, allow login
        if (existingRole == role) {
          return false;
        }

        // If user has multiple roles, check if the requested role is in the list
        if (roles != null && roles.contains(role)) {
          return false;
        }

        // If no role is set yet, allow login
        if (existingRole == null) {
          return false;
        }
      }

      // Only return true if the email exists with a different role and no multiple roles
      return true;
    } catch (e) {
      print('Error checking email with role: $e');
      return false; // In case of error, allow the login
    }
  }

  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut(); // Sign out from Google as well
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  static Stream<User?> get authStateChanges => _auth.authStateChanges();
}
