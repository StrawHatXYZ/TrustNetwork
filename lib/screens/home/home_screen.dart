import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/home_controller.dart';
import 'components/search_bar.dart';
import 'components/post_card.dart';
import '../contacts/contacts_screen.dart';
import '../chats/chat_list_screen.dart';
import '../../services/contacts_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HomeController _controller = HomeController();

  @override
  void initState() {
    super.initState();
    _controller.initialize(context);
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: CustomSearchBar(
          controller: _controller.searchController,
          currentIndex: _controller.currentIndex,
          onSearch: _controller.performSearch,
          userName: _controller.userName,
          onFilterTap: () => _controller.showFilterDialog(context),
        ),
        automaticallyImplyLeading: false, 
      ),
      body: IndexedStack(
        index: _controller.currentIndex,
        children: [
          _buildHomePage(context),
          ContactsPage(searchQuery: _controller.searchController.text),
          const ChatListScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _controller.currentIndex,
        onTap: _controller.setCurrentIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Contacts'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
        ],
        selectedItemColor: const Color(0xFFF4845F),
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  Widget _buildHomePage(BuildContext context) {
    if (_controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4845F)),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        color: const Color(0xFFF4845F),
        onRefresh: _controller.refreshPosts,
        child: CustomScrollView(
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Recent Posts',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142),
                  ),
                ),
              ),
            ),
            if (_controller.isPostsLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4845F)),
                  ),
                ),
              )
            else if (_controller.posts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.post_add, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No posts yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => PostCard(
                    key: ValueKey(_controller.posts[index]['id']),
                    post: _controller.posts[index],
                    contacts: _controller.contacts,
                    registeredContacts: _controller.registeredContacts,
                    onConnect: _controller.createChatRoom,
                  ),
                  childCount: _controller.posts.length,
                  addAutomaticKeepAlives: true,
                  addRepaintBoundaries: true,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _controller.showNewPostSheet(context),
        backgroundColor: const Color(0xFFF4845F),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Post', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
