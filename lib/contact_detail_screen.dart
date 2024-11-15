import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter/cupertino.dart';
import 'package:trust/contacts_service.dart';
import 'dart:typed_data';

class ContactDetailScreen extends StatefulWidget {
  final Contact contact;
  final Function(Contact) onContactUpdated;

  const ContactDetailScreen({
    Key? key,
    required this.contact,
    required this.onContactUpdated,
  }) : super(key: key);

  @override
  _ContactDetailScreenState createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _companyController;
  late TextEditingController _titleController;
  List<TextEditingController> _phoneControllers = [];
  List<TextEditingController> _emailControllers = [];
  List<TextEditingController> _addressControllers = [];
  List<TextEditingController> _websiteControllers = [];
  List<TextEditingController> _socialMediaControllers = [];
  List<TextEditingController> _eventControllers = [];
  late TextEditingController _noteController;
  List<String> _selectedGroups = [];
  Uint8List? _photo;
  final Color appThemeColor = Color(0xFFF4845F);
  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.contact.name.first);
    _lastNameController = TextEditingController(text: widget.contact.name.last);
    _companyController = TextEditingController(text: widget.contact.organizations.isNotEmpty ? widget.contact.organizations.first.company : '');
    _titleController = TextEditingController(text: widget.contact.organizations.isNotEmpty ? widget.contact.organizations.first.title : '');
    _phoneControllers = widget.contact.phones.map((phone) => TextEditingController(text: phone.number)).toList();
    if (_phoneControllers.isEmpty) _phoneControllers.add(TextEditingController());
    _emailControllers = widget.contact.emails.map((email) => TextEditingController(text: email.address)).toList();
    if (_emailControllers.isEmpty) _emailControllers.add(TextEditingController());
    _addressControllers = widget.contact.addresses.map((address) => TextEditingController(text: address.address)).toList();
    if (_addressControllers.isEmpty) _addressControllers.add(TextEditingController());
    _websiteControllers = widget.contact.websites.map((website) => TextEditingController(text: website.url)).toList();
    if (_websiteControllers.isEmpty) _websiteControllers.add(TextEditingController());
    _socialMediaControllers = widget.contact.socialMedias.map((socialMedia) => TextEditingController(text: socialMedia.userName)).toList();
    if (_socialMediaControllers.isEmpty) _socialMediaControllers.add(TextEditingController());
    _eventControllers = widget.contact.events.map((event) => TextEditingController(text: '${event.year}-${event.month}-${event.day}')).toList();
    if (_eventControllers.isEmpty) _eventControllers.add(TextEditingController());
    _noteController = TextEditingController(text: widget.contact.notes.isNotEmpty ? widget.contact.notes.first.note : '');
    _selectedGroups = widget.contact.groups.map((group) => group.id).toList();
    _photo = widget.contact.photo;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Contact'),
        // backgroundColor: appThemeColor,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: _saveContact,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileImage(),
            SizedBox(height: 24),
            _buildTextField(_firstNameController, 'First name', Icons.person),
            _buildTextField(_lastNameController, 'Last name', Icons.person),
            SizedBox(height: 16),
            _buildSectionTitle('Phone Numbers'),
            ..._buildPhoneFields(),
            _buildAddButton('Add Phone', () => _addField(_phoneControllers)),
            SizedBox(height: 16),
            _buildSectionTitle('Email Addresses'),
            ..._buildEmailFields(),
            _buildAddButton('Add Email', () => _addField(_emailControllers)),
            SizedBox(height: 16),
            _buildTextField(_companyController, 'Company', Icons.business),
            _buildTextField(_titleController, 'Title', Icons.work),
            SizedBox(height: 16),
            _buildSectionTitle('Addresses'),
            ..._buildAddressFields(),
            _buildAddButton('Add Address', () => _addField(_addressControllers)),
            SizedBox(height: 16),
            _buildSectionTitle('Websites'),
            ..._buildWebsiteFields(),
            _buildAddButton('Add Website', () => _addField(_websiteControllers)),
            SizedBox(height: 16),
            _buildSectionTitle('Social Media'),
            ..._buildSocialMediaFields(),
            _buildAddButton('Add Social Media', () => _addField(_socialMediaControllers)),
            SizedBox(height: 16),
            _buildSectionTitle('Events'),
            ..._buildEventFields(),
            _buildAddButton('Add Event', () => _addField(_eventControllers)),
            SizedBox(height: 16),
            _buildSectionTitle('Notes'),
            _buildTextField(_noteController, 'Note', Icons.note),
            SizedBox(height: 16),
            _buildSectionTitle('Groups'),
            _buildGroupSelection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return Center(
      child: GestureDetector(
        onTap: () {
          // TODO: Implement photo selection
        },
        child: CircleAvatar(
          radius: 60,
          backgroundColor: appThemeColor,
          backgroundImage: widget.contact.photo != null ? MemoryImage(widget.contact.photo!) : null,
          child: widget.contact.photo == null
              ? Icon(Icons.add_a_photo, size: 40, color: Colors.white)
              : null,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  List<Widget> _buildPhoneFields() {
    return _phoneControllers.map((controller) => _buildPhoneField(controller)).toList();
  }

  Widget _buildPhoneField(TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: () => _removeField(_phoneControllers, controller),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEmailFields() {
    return _emailControllers.map((controller) => _buildEmailField(controller)).toList();
  }

  Widget _buildEmailField(TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: () => _removeField(_emailControllers, controller),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(String label, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.add),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: appThemeColor,
        minimumSize: Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _addField(List<TextEditingController> controllers) {
    setState(() {
      controllers.add(TextEditingController());
    });
  }

  void _removeField(List<TextEditingController> controllers, TextEditingController controller) {
    setState(() {
      controllers.remove(controller);
      controller.dispose();
    });
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  List<Widget> _buildAddressFields() {
    return _addressControllers.map((controller) => _buildAddressField(controller)).toList();
  }

  Widget _buildAddressField(TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: () => _removeField(_addressControllers, controller),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWebsiteFields() {
    return _websiteControllers.map((controller) => _buildWebsiteField(controller)).toList();
  }

  Widget _buildWebsiteField(TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Website',
                prefixIcon: Icon(Icons.web),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: () => _removeField(_websiteControllers, controller),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSocialMediaFields() {
    return _socialMediaControllers.map((controller) => _buildSocialMediaField(controller)).toList();
  }

  Widget _buildSocialMediaField(TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Social Media',
                prefixIcon: Icon(Icons.people),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: () => _removeField(_socialMediaControllers, controller),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEventFields() {
    return _eventControllers.map((controller) => _buildEventField(controller)).toList();
  }

  Widget _buildEventField(TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.datetime,
              decoration: InputDecoration(
                labelText: 'Event (YYYY-MM-DD)',
                prefixIcon: Icon(Icons.event),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: () => _removeField(_eventControllers, controller),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSelection() {
    // Implement group selection logic here
    // You may want to use a MultiSelectChip or CheckboxListTile for this
    return Container(); // Placeholder
  }

  void _saveContact() async {
    // Update the contact object with new values
    widget.contact.name.first = _firstNameController.text;
    widget.contact.name.last = _lastNameController.text;
    // Update the displayName
    widget.contact.displayName = '${_firstNameController.text} ${_lastNameController.text}'.trim();
    widget.contact.organizations = [Organization(company: _companyController.text, title: _titleController.text)];
    widget.contact.phones = _phoneControllers
        .where((controller) => controller.text.isNotEmpty)
        .map((controller) => Phone(controller.text))
        .toList();
    widget.contact.emails = _emailControllers
        .where((controller) => controller.text.isNotEmpty)
        .map((controller) => Email(controller.text))
        .toList();
    widget.contact.addresses = _addressControllers
        .where((controller) => controller.text.isNotEmpty)
        .map((controller) => Address(controller.text))
        .toList();
    widget.contact.websites = _websiteControllers
        .where((controller) => controller.text.isNotEmpty)
        .map((controller) => Website(controller.text))
        .toList();
    widget.contact.socialMedias = _socialMediaControllers
        .where((controller) => controller.text.isNotEmpty)
        .map((controller) => SocialMedia(controller.text))
        .toList();
    widget.contact.events = _eventControllers
        .where((controller) => controller.text.isNotEmpty)
        .map((controller) {
          final parts = controller.text.split('-');
          return Event(
            year: int.parse(parts[0]),
            month: int.parse(parts[1]),
            day: int.parse(parts[2])
          );
        })
        .toList();
    widget.contact.notes = [Note(_noteController.text)];
    widget.contact.groups = _selectedGroups.map((groupId) => Group(groupId, '')).toList();
    widget.contact.photo = _photo;

    try {
      // Update the contact in local storage
      await ContactService.updateContact(widget.contact);
      
      // Call the onContactUpdated callback
      widget.onContactUpdated(widget.contact);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Contact updated successfully')),
      );

      // Close the edit screen
      Navigator.of(context).pop();
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update contact: $e')),
      );
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    _firstNameController.dispose();
    _lastNameController.dispose();
    _companyController.dispose();
    _titleController.dispose();
    _phoneControllers.forEach((controller) => controller.dispose());
    _emailControllers.forEach((controller) => controller.dispose());
    _addressControllers.forEach((controller) => controller.dispose());
    _websiteControllers.forEach((controller) => controller.dispose());
    _socialMediaControllers.forEach((controller) => controller.dispose());
    _eventControllers.forEach((controller) => controller.dispose());
    _noteController.dispose();
    super.dispose();
  }
}
