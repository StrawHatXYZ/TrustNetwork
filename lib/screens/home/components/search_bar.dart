import 'package:flutter/material.dart';
import '../../profile/profile_page.dart';

class CustomSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final int currentIndex;
  final Function(String) onSearch;
  final String userName;
  final VoidCallback onFilterTap;

  const CustomSearchBar({
    required this.controller,
    required this.currentIndex,
    required this.onSearch,
    required this.userName,
    required this.onFilterTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: _getSearchHint(),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFF4845F)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          controller.clear();
                          onSearch('');
                        },
                      ),
                    if (currentIndex == 1)
                      IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: onFilterTap,
                      ),
                  ],
                ),
              ),
              onChanged: onSearch,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF4845F), width: 2),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              backgroundImage: NetworkImage(
                'https://ui-avatars.com/api/?background=0D8ABC&color=fff&name=${Uri.encodeComponent(userName)}&rounded=true'
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getSearchHint() {
    switch (currentIndex) {
      case 0:
        return 'Search posts...';
      case 1:
        return 'Search contacts...';
      case 2:
        return 'Search chats...';
      default:
        return 'Search...';
    }
  }
}