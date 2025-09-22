import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: '99220041339@klu.ac.in');
  final _passwordController = TextEditingController(text: '99220041339');
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedRole = 'customer'; // Default role

  Future<void> _handleGoogleSignIn() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get Google user
      final googleUser = await UserService.getGoogleUser();
      
      // Debug output
      print('Google Sign-In Status: ${googleUser != null ? 'User selected' : 'Cancelled'}');
      
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Google sign-in was cancelled.';
        });
        return;
      }
      
      print('Google Sign-In Email: ${googleUser.email}');
      
      // Check if this email is already used with a different role
      final bool emailUsedWithDifferentRole = await UserService.isEmailUsedWithRole(googleUser.email, _selectedRole);
      if (emailUsedWithDifferentRole) {
        // Show a dialog to confirm role change
        if (!mounted) return;
        
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Account Exists'),
              content: const Text(
                'This email is already registered with a different role. Would you like to add this role to your account?',
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: const Text('Add Role'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        );
        
        if (confirm != true) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Sign-in cancelled.';
          });
          return;
        }
      }
      
      // Proceed with sign-in
      final userCredential = await UserService.signInWithGoogle(role: _selectedRole);
      
      if (!mounted) return;
      
      // Navigate based on role
      switch (_selectedRole) {
        case 'blogger':
          Navigator.pushReplacementNamed(context, '/blogger-home');
          break;
        case 'restaurant':
          Navigator.pushReplacementNamed(context, '/restaurant/home');
          break;
        case 'customer':
        default:
          Navigator.pushReplacementNamed(context, '/home');
          break;
      }
    } catch (e) {
      print('Google Sign-In Error: $e');
      
      if (!mounted) return;
      
      setState(() {
        if (e.toString().contains('account-exists-with-different-credential')) {
          _errorMessage = 'This email is already used with a different sign-in method. Try another login method.';
        } else if (e.toString().contains('ERROR_ABORTED_BY_USER')) {
          _errorMessage = 'Google sign-in was cancelled by user.';
        } else if (e.toString().contains('network_error')) {
          _errorMessage = 'Network error. Please check your internet connection.';
        } else if (e.toString().contains('invalid-credential')) {
          _errorMessage = 'Unable to authenticate with Google. Please try again.';
        } else if (e.toString().contains('user-disabled')) {
          _errorMessage = 'This account has been disabled. Please contact support.';
        } else if (e.toString().contains('operation-not-allowed')) {
          _errorMessage = 'Google Sign-In is not enabled. Please contact support.';
        } else if (e.toString().contains('popup_closed_by_user')) {
          _errorMessage = 'Sign-in popup was closed. Please try again.';
        } else if (e.toString().contains('popup_blocked_by_browser')) {
          _errorMessage = 'Sign-in popup was blocked. Please allow popups and try again.';
        } else if (e.toString().contains('sign_in_failed')) {
          _errorMessage = 'Google Sign-In failed. Please try again.';
        } else if (e.toString().contains('sign_in_canceled')) {
          _errorMessage = 'Google Sign-In was canceled. Please try again.';
        } else if (e.toString().contains('sign_in_required')) {
          _errorMessage = 'Please sign in to continue.';
        } else {
          _errorMessage = 'Failed to sign in: ${e.toString()}';
        }
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkEmailWithRole(String email, String selectedRole) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        return false; // Email doesn't exist yet, allow login
      }
      
      // If user document exists but doesn't have metadata.role or it's the same as selected role, allow login
      for (var doc in querySnapshot.docs) {
        final userData = doc.data();
        final existingRole = userData['metadata']?['role'] as String?;
        
        // If there's no role set or it matches the selected role, login is allowed
        if (existingRole == null || existingRole == selectedRole) {
          return false; // Role is compatible, allow login
        }
      }
      
      // Email exists with an incompatible role
      return true;
    } catch (e) {
      print('Error checking email role: $e');
      return false; // In case of error, allow the login
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final email = _emailController.text.trim();
        final password = _passwordController.text;
        
        // First try standard sign in without role checks
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          
          // If successful, update the role if needed
          await UserService.signInWithEmail(
            email: email,
            password: password,
            role: _selectedRole,
          );
          
          if (mounted) {
            // Navigate based on role
            switch (_selectedRole) {
              case 'blogger':
                Navigator.pushReplacementNamed(context, '/blogger-home');
                break;
              case 'restaurant':
                Navigator.pushReplacementNamed(context, '/restaurant/home');
                break;
              case 'customer':
              default:
                Navigator.pushReplacementNamed(context, '/home');
                break;
            }
          }
        } on FirebaseAuthException catch (authError) {
          if (authError.code == 'user-not-found' || authError.code == 'wrong-password') {
            // Standard auth errors, show these to the user
            if (mounted) {
              setState(() {
                if (authError.code == 'user-not-found') {
                  _errorMessage = 'No user found with this email. Please sign up first.';
                } else if (authError.code == 'wrong-password') {
                  _errorMessage = 'Incorrect password. Please try again.';
                } else {
                  _errorMessage = authError.message ?? 'An error occurred during login';
                }
                _isLoading = false;
              });
            }
          } else {
            // Other auth errors
            throw authError;
          }
        }
      } catch (e) {
        print('Login Error: $e');
        if (mounted) {
          setState(() {
            _errorMessage = 'Login failed. Please check your credentials and try again.';
            _isLoading = false;
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 100,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Greedy Bites',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Your Role',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Role selection segment
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'customer',
                        label: Text('Customer'),
                        icon: Icon(Icons.person),
                      ),
                      ButtonSegment(
                        value: 'blogger',
                        label: Text('Blogger'),
                        icon: Icon(Icons.edit),
                      ),
                      ButtonSegment(
                        value: 'restaurant',
                        label: Text('Restaurant'),
                        icon: Icon(Icons.restaurant),
                      ),
                    ],
                    selected: {_selectedRole},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedRole = newSelection.first;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Login as ${_selectedRole.substring(0, 1).toUpperCase() + _selectedRole.substring(1)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'OR',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      icon: const Icon(
                        Icons.g_mobiledata,
                        size: 24,
                        color: Colors.red,
                      ),
                      label: Text('Sign in with Google as ${_selectedRole.substring(0, 1).toUpperCase() + _selectedRole.substring(1)}'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.pushNamed(context, '/signup');
                          },
                    child: const Text('Don\'t have an account? Sign Up'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 