import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/user_service.dart';
import '../login_page.dart';
import 'edit_profile_page.dart';
import 'notification_settings_page.dart';
import 'account_settings_page.dart';
import 'help_support_page.dart';

class BloggerProfilePage extends StatefulWidget {
  const BloggerProfilePage({super.key});

  @override
  State<BloggerProfilePage> createState() => _BloggerProfilePageState();
}

class _BloggerProfilePageState extends State<BloggerProfilePage> {
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    return _isLoading 
      ? const Center(child: CircularProgressIndicator()) 
      : FutureBuilder(
          future: FirebaseAuth.instance.currentUser != null 
              ? _getUserDataSafely(FirebaseAuth.instance.currentUser!.uid)
              : Future.value(null),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              // Handle permission denied errors gracefully
              if (snapshot.error.toString().contains('permission-denied')) {
                final currentUser = FirebaseAuth.instance.currentUser;
                final newUser = {
                  'name': currentUser?.displayName ?? 'Blogger',
                  'email': currentUser?.email ?? '',
                  'photoURL': currentUser?.photoURL,
                };
                return _buildProfileContent(newUser);
              }
              
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {});
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              // Create a basic profile if user document doesn't exist
              final currentUser = FirebaseAuth.instance.currentUser;
              final newUser = {
                'name': currentUser?.displayName ?? 'Blogger',
                'email': currentUser?.email ?? '',
                'photoURL': currentUser?.photoURL,
              };

              return _buildProfileContent(newUser);
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>;
            return _buildProfileContent(userData);
          },
        );
  }

  // Safe method to get user data with error handling
  Future<dynamic> _getUserDataSafely(String userId) async {
    try {
      return await UserService.getUserData(userId);
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        // Return a mock document that doesn't exist
        return MockDocumentSnapshot();
      }
      rethrow;
    }
  }

  Widget _buildProfileContent(Map<String, dynamic> userData) {
    final socialMedia = userData['socialMedia'] as Map<String, dynamic>? ?? {};
    final specialties = userData['specialties'] as List<dynamic>? ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile Image
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundImage: userData['profileImageUrl'] != null
                    ? NetworkImage(userData['profileImageUrl'])
                    : null,
                child: userData['profileImageUrl'] == null
                    ? Text(
                        (userData['name'] as String?)?.substring(0, 1).toUpperCase() ?? 'B',
                        style: const TextStyle(fontSize: 40),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () {
                      // Navigate to edit profile
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfilePage(userData: userData),
                        ),
                      ).then((_) => setState(() {})); // Refresh after returning
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // User Name
          Text(
            userData['name'] ?? 'Blogger',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // User Email
          Text(
            userData['email'] ?? '',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),

          // Phone Number
          if (userData['phoneNumber'] != null) ...[
            Text(
              userData['phoneNumber'],
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Bio
          if (userData['bio'] != null) ...[
            Text(
              userData['bio'],
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],

          // Food Specialties
          if (specialties.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: specialties.map((specialty) => 
                Chip(
                  label: Text(specialty),
                  backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                ),
              ).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Social Media Links
          if (socialMedia.isNotEmpty && 
              socialMedia.values.any((value) => value != null && value.toString().isNotEmpty)) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (socialMedia['facebook'] != null && socialMedia['facebook'].toString().isNotEmpty)
                  _buildSocialIcon(Icons.facebook, Colors.blue),
                if (socialMedia['instagram'] != null && socialMedia['instagram'].toString().isNotEmpty)
                  _buildSocialIcon(Icons.camera_alt, Colors.purple),
                if (socialMedia['twitter'] != null && socialMedia['twitter'].toString().isNotEmpty)
                  _buildSocialIcon(Icons.travel_explore, Colors.lightBlue),
                if (socialMedia['youtube'] != null && socialMedia['youtube'].toString().isNotEmpty)
                  _buildSocialIcon(Icons.video_library, Colors.red),
                if (socialMedia['website'] != null && socialMedia['website'].toString().isNotEmpty)
                  _buildSocialIcon(Icons.language, Colors.teal),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Stats row
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 16,
            children: [
              _buildStatItem('Posts', '0'),
              _buildStatItem('Followers', '0'),
              _buildStatItem('Following', '0'),
            ],
          ),
          const SizedBox(height: 32),

          // Profile Options
          _buildProfileOption(
            icon: Icons.edit_note,
            title: 'Edit Profile',
            onTap: () {
              // Navigate to edit profile
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfilePage(userData: userData),
                ),
              ).then((_) => setState(() {})); // Refresh after returning
            },
          ),
          _buildProfileOption(
            icon: Icons.notifications_outlined,
            title: 'Notification Settings',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsPage(),
                ),
              ).then((_) => setState(() {})); // Refresh after returning
            },
          ),
          _buildProfileOption(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Settings',
            onTap: () {
              // TODO: Implement privacy settings
            },
          ),
          _buildProfileOption(
            icon: Icons.settings_outlined,
            title: 'Account Settings',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountSettingsPage(),
                ),
              ).then((_) => setState(() {})); // Refresh after returning
            },
          ),
          _buildProfileOption(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HelpSupportPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Sign Out Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  await UserService.signOut();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  print('Error signing out: $e');
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: color.withOpacity(0.2),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// Mock document snapshot for handling permission denied errors
class MockDocumentSnapshot {
  bool get exists => false;
  Map<String, dynamic>? data() => null;
} 