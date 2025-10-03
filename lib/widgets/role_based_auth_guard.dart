import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/direct_access_page.dart';
import '../pages/home_page.dart';
// Restaurant home removed in customer/blogger-only build
import '../pages/blogger/blogger_home_page.dart';
import '../utils/error_handler.dart';

class RoleBasedAuthGuard extends StatelessWidget {
  const RoleBasedAuthGuard({super.key});
  static const List<String> _allowedRolesForThisApp = ['customer', 'blogger'];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // Handle authentication state
        if (snapshot.hasData && snapshot.data != null) {
          // User is authenticated, check their role
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, userSnapshot) {
              // Handle loading state for Firestore data
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              // Handle error state
              if (userSnapshot.hasError) {
                ErrorHandler.logError(userSnapshot.error, null);
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          ErrorHandler.getFirebaseErrorMessage(userSnapshot.error),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              // Check if user data exists
              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                debugPrint('User document does not exist for uid: ${snapshot.data?.uid}');
                return const DirectAccessPage();
              }
              
              try {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                String? userRole;
                
                // Check for role in different locations (for backward compatibility)
                if (userData['metadata'] != null && userData['metadata'] is Map) {
                  userRole = (userData['metadata'] as Map<String, dynamic>)['role'] as String?;
                } 
                
                if (userRole == null && userData.containsKey('role')) {
                  userRole = userData['role'] as String?;
                }
                
                debugPrint('User role from Firestore: $userRole');
                debugPrint('User data: $userData');
                
                // Enforce allowed roles and route to appropriate page
                if (userRole == 'customer' || userRole == 'user') {
                  debugPrint('Navigating to customer home page');
                  return const HomePage();
                } else if (userRole == 'blogger') {
                  debugPrint('Navigating to blogger home page');
                  return const BloggerHomePage();
                } else {
                  // No role found or role not allowed in this app
                  debugPrint('Role not allowed or not recognized: $userRole, signing out user');
                  
                  // Show a dialog to the user to inform them about the issue
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Access not allowed'),
                          content: const Text('This account is not permitted in this application.'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                FirebaseAuth.instance.signOut();
                                Navigator.of(context).pop();
                              },
                              child: const Text('OK'),
                            ),
                          ],
                        );
                      },
                    );
                  });
                  
                  // Send them to login page after a short delay
                  Future.delayed(const Duration(seconds: 2), () {
                    FirebaseAuth.instance.signOut();
                  });
                  
                  return const Scaffold(
                    body: Center(
                      child: Text('Redirecting to login page...'),
                    ),
                  );
                }
              } catch (e, stackTrace) {
                ErrorHandler.logError(e, stackTrace);
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                        const SizedBox(height: 16),
                        const Text(
                          'Error parsing user data. Please try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          );
        }
        
        // User is not authenticated, show direct access page
        return const DirectAccessPage();
      },
    );
  }
} 