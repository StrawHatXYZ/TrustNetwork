import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../contact_detail_screen.dart';

class ContactViewScreen extends StatelessWidget {
  final Contact contact;
  final Function(Contact) onContactUpdated;

  const ContactViewScreen({
    Key? key,
    required this.contact,
    required this.onContactUpdated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(contact.displayName),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ContactDetailScreen(
                    contact: contact,
                    onContactUpdated: onContactUpdated,
                  ),
                ),
              );
              if (result != null) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Contact Avatar
            CircleAvatar(
              backgroundColor: const Color(0xFFF4845F),
              radius: 60,
              child: Text(
                contact.displayName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Contact Name
            Text(
              contact.displayName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            // Quick Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.phone,
                  label: 'Call',
                  onTap: () {
                    // Implement call functionality
                  },
                ),
                _buildActionButton(
                  icon: Icons.message,
                  label: 'Message',
                  onTap: () {
                    // Implement message functionality
                  },
                ),
                _buildActionButton(
                  icon: Icons.videocam,
                  label: 'Video',
                  onTap: () {
                    // Implement video call functionality
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Contact Information
            _buildContactInfoSection(contact),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, size: 32, color: const Color(0xFFF4845F)),
          onPressed: onTap,
        ),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFF4845F),
          ),
        ),
      ],
    );
  }

  Widget _buildContactInfoSection(Contact contact) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phone Numbers
          if (contact.phones.isNotEmpty) ...[
            _buildSectionHeader('Phone Numbers'),
            ...contact.phones.map((phone) => _buildInfoTile(
                  icon: Icons.phone,
                  title: phone.number,
                  subtitle: 'phone',
                )),
            const SizedBox(height: 24),
          ],
          // Emails
          if (contact.emails.isNotEmpty) ...[
            _buildSectionHeader('Email Addresses'),
            ...contact.emails.map((email) => _buildInfoTile(
                  icon: Icons.email,
                  title: email.address,
                  subtitle: 'email',
                )),
            const SizedBox(height: 24),
          ],
          // Addresses
          if (contact.addresses.isNotEmpty) ...[
            _buildSectionHeader('Addresses'),
            ...contact.addresses.map((address) => _buildInfoTile(
                  icon: Icons.location_on,
                  title: [
                    address.street,
                    address.city,
                    address.state,
                    address.postalCode,
                    address.country,
                  ].where((e) => e.isNotEmpty).join(', '),
                  subtitle: 'address',
                )),
            const SizedBox(height: 24),
          ],
          // Organizations
          if (contact.organizations.isNotEmpty) ...[
            _buildSectionHeader('Organizations'),
            ...contact.organizations.map((org) => _buildInfoTile(
                  icon: Icons.business,
                  title: org.company,
                  subtitle: org.title.isNotEmpty ? org.title : 'company',
                )),
            const SizedBox(height: 24),
          ],
          // Websites
          if (contact.websites.isNotEmpty) ...[
            _buildSectionHeader('Websites'),
            ...contact.websites.map((website) => _buildInfoTile(
                  icon: Icons.web,
                  title: website.url,
                  subtitle: 'website',
                )),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  // Helper method to create consistent section headers
  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF4845F)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
