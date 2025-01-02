import 'package:flutter/material.dart';

class NewPostSheet extends StatefulWidget {
  final Function(String content, String jobTitle, String company, String location, String skills) onPost;

  const NewPostSheet({
    required this.onPost,
    super.key,
  });

  @override
  State<NewPostSheet> createState() => _NewPostSheetState();
}

class _NewPostSheetState extends State<NewPostSheet> {
  final TextEditingController _jobTitleController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _jobTitleController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              const Text(
                'New Post',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 48), // Balance the close button
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _jobTitleController,
            decoration: InputDecoration(
              hintText: "Job Title (e.g., Flutter Developer)",
              prefixIcon: const Icon(Icons.work_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
          
          const SizedBox(height: 12),
          TextField(
            controller: _companyController,
            decoration: InputDecoration(
              hintText: "Company Name",
              prefixIcon: const Icon(Icons.business),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),

          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            decoration: InputDecoration(
              hintText: "Location (e.g., Bangalore)",
              prefixIcon: const Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),

          const SizedBox(height: 12),
          TextField(
            controller: _skillsController,
            decoration: InputDecoration(
              hintText: "Skills (eg, Flutter, React, … )",
              prefixIcon: const Icon(Icons.psychology),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),

          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _handlePost,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4845F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
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
                : const Text(
                    'Post',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePost() async {
    //dismiss the post sheet
    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      final StringBuffer postContent = StringBuffer();
      final String jobTitle = _jobTitleController.text.trim();
      final String company = _companyController.text.trim();
      final String location = _locationController.text.trim();
      final String skills = _skillsController.text.trim();

      // Job title is the minimum required field
      if (jobTitle.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a job title to continue'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom:20, // Add space from bottom navigation/toolbar
              left: 20,
              right: 20,
            ),
          ),
        );
        return;
      }

      // Build the content based on available fields
      if (company.isNotEmpty && location.isNotEmpty) {
        // All location and company info available
        postContent.write('Looking for $jobTitle at $company in $location');
      } else if (company.isNotEmpty) {
        // Only company info available
        postContent.write('Looking for $jobTitle at $company');
      } else if (location.isNotEmpty) {
        // Only location info available
        postContent.write('Looking for $jobTitle in $location');
      } else {
        // Only job title available
        postContent.write('Looking for $jobTitle');
      }

      // Add skills if available
      if (skills.isNotEmpty) {
        postContent.write('. Required skills: $skills');
      }

      await widget.onPost(
        postContent.toString(),
        jobTitle,
        company,
        location,
        skills,
      );
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}