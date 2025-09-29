import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/date_format_util.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitSupportRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Here you would typically send the support request to your backend
      // For demo purposes, we'll just show a success message
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support request submitted successfully')),
        );

        // Clear form
        _subjectController.clear();
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid URL')),
        );
      }
      return;
    }
    final Uri uri = Uri.parse(url);
    if (!uri.hasScheme) {
      // Default to https for bare domains
      final String normalized = 'https://$url';
      return _launchUrl(normalized);
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }

  Widget _buildFaqItem(String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(answer),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Help Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                          child: Icon(
                            Icons.support_agent,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Need help with your blogger account?',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Our support team is here to help you with any issues',
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () {
                        // Scroll to contact form
                        Scrollable.ensureVisible(
                          _formKey.currentContext ?? context,
                          alignment: 0.5, 
                          duration: const Duration(milliseconds: 500),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'Contact Support',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Frequently Asked Questions
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 16),
            
            // FAQ List
            Card(
              elevation: 2,
              child: Column(
                children: [
                  _buildFaqItem(
                    'How do I create a new blog post?',
                    'To create a new blog post, go to your dashboard and click on the "+" button in the bottom right corner. Select "Create Post" from the menu. Fill in the details of your post, including text, images, and tags, then click "Publish" when you\'re ready.',
                  ),
                  _buildFaqItem(
                    'How do I increase my followers?',
                    'To increase your followers: 1) Post quality content regularly, 2) Use relevant tags, 3) Engage with other bloggers, 4) Share your posts on social media, 5) Respond to comments on your posts, and 6) Collaborate with other food bloggers.',
                  ),
                  _buildFaqItem(
                    'Can I edit or delete my reviews?',
                    'Yes, you can edit or delete your restaurant reviews. Go to your profile, find the review you want to modify, and click on the three dots menu. From there, you can choose to edit or delete the review.',
                  ),
                  _buildFaqItem(
                    'How do I create reels?',
                    'To create a reel, tap the "+" button on your dashboard and select "Create Reel". You can upload a short video (up to 30 seconds), add captions, music, and tags. Once you\'re satisfied with your reel, tap "Post" to publish it.',
                  ),
                  _buildFaqItem(
                    'How do I change my account privacy settings?',
                    'Go to your profile, tap on "Account Settings", and navigate to the "Content & Privacy" section. Here you can adjust who can see your posts, comment on them, and send you direct messages.',
                  ),
                  _buildFaqItem(
                    'How do I book a table through the app?',
                    'Navigate to the restaurant page you want to book. Tap on the "Book Table" button, select your preferred date, time, and number of guests. Review the details and confirm your booking.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Tutorials Section
            const Text(
              'Video Tutorials',
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.play_circle_fill, color: Colors.red),
                    title: const Text('Getting Started as a Food Blogger'),
                    subtitle: const Text('5:20 mins'),
                    onTap: () => _launchUrl('https://www.youtube.com/watch?v=example1'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.play_circle_fill, color: Colors.red),
                    title: const Text('How to Create Engaging Food Content'),
                    subtitle: const Text('8:15 mins'),
                    onTap: () => _launchUrl('https://www.youtube.com/watch?v=example2'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.play_circle_fill, color: Colors.red),
                    title: const Text('Food Photography Tips for Bloggers'),
                    subtitle: const Text('12:05 mins'),
                    onTap: () => _launchUrl('https://www.youtube.com/watch?v=example3'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.play_circle_fill, color: Colors.red),
                    title: const Text('Creating Food Reels That Go Viral'),
                    subtitle: const Text('7:30 mins'),
                    onTap: () => _launchUrl('https://www.youtube.com/watch?v=example4'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Contact Form
            const Text(
              'Contact Support',
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Email us directly at support@greedybites.com or fill out this form:'),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a subject';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your message';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitSupportRequest,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator()
                              : const Text('Submit Request'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Other Support Options
            const Text(
              'Other Support Options',
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.menu_book_outlined, color: Colors.blue),
                    title: const Text('Blogger Documentation'),
                    subtitle: const Text('Learn about all features and capabilities'),
                    onTap: () => _launchUrl('https://docs.greedybites.com/blogger'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.group_outlined, color: Colors.green),
                    title: const Text('Blogger Community'),
                    subtitle: const Text('Connect with fellow food bloggers'),
                    onTap: () => _launchUrl('https://community.greedybites.com'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.contact_phone_outlined, color: Colors.orange),
                    title: const Text('Support Hotline'),
                    subtitle: const Text('Call us at: +91 1800-123-4567'),
                    onTap: () => _launchUrl('tel:+918001234567'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline, color: Colors.purple),
                    title: const Text('Live Chat'),
                    subtitle: const Text('Chat with our support team (9 AM - 6 PM IST)'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Live chat will open in the app soon')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
} 