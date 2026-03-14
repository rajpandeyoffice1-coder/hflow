import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  static const double _headerHeight = 56;

  final supabase = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();

  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;

  late AnimationController _liquidController;
  late Animation<double> _liquidAnimation;

  Map<String, dynamic>? profileData;
  String? fullName;
  String? email;
  String? phoneNumber;
  String? userId;
  String? avatarUrl;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _setupRealtimeSubscription();

    _liquidController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _liquidAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _liquidController, curve: Curves.easeInOut),
    );

    _liquidController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _liquidController.dispose();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        supabase
            .channel('profile_changes')
            .onPostgresChanges(
          table: 'profiles',
          callback: (payload) {
            if (mounted && payload.newRecord['id'] == userId) {
              _loadProfileData();
            }
          },
          event: PostgresChangeEvent.all,
        )
            .subscribe();
      }
    } catch (e) {
      debugPrint('Error setting up realtime subscription: $e');
    }
  }

  Future<void> _loadProfileData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      email = user.email;
      userId = user.id;

      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        profileData = Map<String, dynamic>.from(response);
        fullName = profileData?['full_name'] ?? '';
        phoneNumber = profileData?['phone_number'] ?? '';
        avatarUrl = profileData?['avatar_url'];

        _nameController.text = fullName ?? '';
        _phoneController.text = phoneNumber ?? '';
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading profile: $e';
      });
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _updateProfile() async {
    setState(() {
      isSaving = true;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final updates = {
        'full_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase
          .from('profiles')
          .update(updates)
          .eq('id', user.id);

      setState(() {
        fullName = _nameController.text.trim();
        phoneNumber = _phoneController.text.trim();
      });

      if (mounted) {
        _showSuccessSnackBar('Profile updated successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error updating profile: $e');
      }
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<void> _showEditProfileBottomSheet() async {
    final nameController = TextEditingController(text: fullName);
    final phoneController = TextEditingController(text: phoneNumber);
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A1F2E).withOpacity(0.95),
                const Color(0xFF0B0F1A).withOpacity(0.98),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _liquidAnimation,
                builder: (context, child) {
                  return Stack(
                    children: [
                      Positioned(
                        top: -50,
                        right: -30,
                        child: Transform.rotate(
                          angle: _liquidAnimation.value * 0.5,
                          child: _LiquidBlob3D(
                            size: 200,
                            color: const Color(0xFF9333EA).withOpacity(0.15),
                            animation: _liquidAnimation.value,
                            opacity: 0.15,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -50,
                        left: -30,
                        child: Transform.rotate(
                          angle: _liquidAnimation.value * 0.3,
                          child: _LiquidBlob3D(
                            size: 250,
                            color: const Color(0xFF3B82F6).withOpacity(0.12),
                            animation: _liquidAnimation.value,
                            opacity: 0.12,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF5B8CFF), Color(0xFF9333EA)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF5B8CFF).withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Edit Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Center(
                            child: Stack(
                              children: [
                                _GlassMorphismCard(
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const RadialGradient(
                                        colors: [
                                          Color(0xFF5B8CFF),
                                          Color(0xFF9333EA),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: CircleAvatar(
                                        radius: 54,
                                        backgroundColor: Colors.transparent,
                                        backgroundImage: avatarUrl != null
                                            ? NetworkImage(avatarUrl!)
                                            : null,
                                        child: avatarUrl == null
                                            ? Text(
                                          fullName?.isNotEmpty == true
                                              ? fullName![0].toUpperCase()
                                              : email?[0].toUpperCase() ?? '?',
                                          style: const TextStyle(
                                            fontSize: 40,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _pickImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF5B8CFF), Color(0xFF9333EA)],
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF5B8CFF).withOpacity(0.4),
                                            blurRadius: 15,
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          _buildGlassTextField(
                            controller: nameController,
                            label: 'Full Name',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 20),
                          _buildGlassTextField(
                            controller: phoneController,
                            label: 'Phone Number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 20),
                          _GlassMorphismCard(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.email_outlined,
                                      color: Color(0xFF5B8CFF),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Email',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          email ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          _AnimatedGlassButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                              setSheetState(() => isSaving = true);
                              setState(() => isSaving = true);

                              _nameController.text = nameController.text;
                              _phoneController.text = phoneController.text;
                              await _updateProfile();

                              setSheetState(() => isSaving = false);
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                            child: isSaving
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                              'Save Changes',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChangePasswordBottomSheet() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSaving = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A1F2E).withOpacity(0.95),
                const Color(0xFF0B0F1A).withOpacity(0.98),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _liquidAnimation,
                builder: (context, child) {
                  return Stack(
                    children: [
                      Positioned(
                        top: -50,
                        right: -30,
                        child: Transform.rotate(
                          angle: _liquidAnimation.value * 0.7,
                          child: _LiquidBlob3D(
                            size: 180,
                            color: const Color(0xFF3B82F6).withOpacity(0.15),
                            animation: _liquidAnimation.value,
                            opacity: 0.15,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -50,
                        left: -30,
                        child: Transform.rotate(
                          angle: _liquidAnimation.value * 0.4,
                          child: _LiquidBlob3D(
                            size: 220,
                            color: const Color(0xFF9333EA).withOpacity(0.12),
                            animation: _liquidAnimation.value,
                            opacity: 0.12,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF5B8CFF), Color(0xFF9333EA)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF5B8CFF).withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Change Password',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildGlassPasswordField(
                            controller: currentPasswordController,
                            label: 'Current Password',
                            icon: Icons.lock_outline,
                            obscureText: obscureCurrent,
                            onToggle: () => setSheetState(() => obscureCurrent = !obscureCurrent),
                          ),
                          const SizedBox(height: 20),
                          _buildGlassPasswordField(
                            controller: newPasswordController,
                            label: 'New Password',
                            icon: Icons.lock_reset,
                            obscureText: obscureNew,
                            onToggle: () => setSheetState(() => obscureNew = !obscureNew),
                          ),
                          const SizedBox(height: 20),
                          _buildGlassPasswordField(
                            controller: confirmPasswordController,
                            label: 'Confirm Password',
                            icon: Icons.check_circle_outline,
                            obscureText: obscureConfirm,
                            onToggle: () => setSheetState(() => obscureConfirm = !obscureConfirm),
                          ),
                          const SizedBox(height: 20),
                          _GlassMorphismCard(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Password Requirements:',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildRequirement(
                                    'At least 8 characters',
                                    newPasswordController.text.length >= 8,
                                  ),
                                  _buildRequirement(
                                    'Contains uppercase letter',
                                    newPasswordController.text.contains(RegExp(r'[A-Z]')),
                                  ),
                                  _buildRequirement(
                                    'Contains lowercase letter',
                                    newPasswordController.text.contains(RegExp(r'[a-z]')),
                                  ),
                                  _buildRequirement(
                                    'Contains number',
                                    newPasswordController.text.contains(RegExp(r'[0-9]')),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          _AnimatedGlassButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                              if (newPasswordController.text != confirmPasswordController.text) {
                                _showErrorSnackBar('Passwords do not match');
                                return;
                              }

                              setSheetState(() => isSaving = true);
                              setState(() => isSaving = true);

                              await _changePasswordWithValues(
                                currentPasswordController.text,
                                newPasswordController.text,
                              );

                              setSheetState(() => isSaving = false);
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                            child: isSaving
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                              'Update Password',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? Colors.green : Colors.white.withOpacity(0.3),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.green : Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePasswordWithValues(String currentPassword, String newPassword) async {
    try {
      final user = supabase.auth.currentUser;
      if (user?.email == null) throw Exception('User email not found');

      await supabase.auth.signInWithPassword(
        email: user!.email!,
        password: currentPassword,
      );

      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (mounted) {
        _showSuccessSnackBar('Password changed successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    }
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return _GlassMorphismCard(
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF5B8CFF)),
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          border: InputBorder.none,
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildGlassPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    return _GlassMorphismCard(
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF5B8CFF)),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText ? Icons.visibility_off : Icons.visibility,
              color: Colors.white.withOpacity(0.5),
            ),
            onPressed: onToggle,
          ),
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          border: InputBorder.none,
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _changePassword() async {
    await _showChangePasswordBottomSheet();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        await _uploadAvatar(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error picking image: $e');
      }
    }
  }

  Future<void> _uploadAvatar(File imageFile) async {
    setState(() {
      isSaving = true;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final fileExt = path.extension(imageFile.path);
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}$fileExt';
      final filePath = 'avatars/$fileName';

      await supabase.storage.from('avatars').upload(
        filePath,
        imageFile,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: true,
        ),
      );

      final publicUrl = supabase.storage.from('avatars').getPublicUrl(filePath);

      await supabase
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', user.id);

      setState(() {
        avatarUrl = publicUrl;
      });

      if (mounted) {
        _showSuccessSnackBar('Profile picture updated successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error uploading image: $e');
      }
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text('Delete Account', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete your account? This action is permanent and cannot be undone. All your data will be lost.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please contact support to delete your account'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05060A),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _liquidAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0B0F1A), Color(0xFF05060A)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -120 + 20 * math.sin(_liquidAnimation.value),
                    left: -100 + 30 * math.cos(_liquidAnimation.value * 0.5),
                    child: Transform.rotate(
                      angle: _liquidAnimation.value * 0.3,
                      child: _LiquidBlob3D(
                        width: 320,
                        height: 420,
                        color: const Color(0xFF9333EA),
                        opacity: 0.28,
                        animation: _liquidAnimation.value,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -160 + 20 * math.cos(_liquidAnimation.value * 0.7),
                    right: -120 + 30 * math.sin(_liquidAnimation.value * 0.4),
                    child: Transform.rotate(
                      angle: _liquidAnimation.value * 0.5,
                      child: _LiquidBlob3D(
                        width: 380,
                        height: 460,
                        color: const Color(0xFF3B82F6),
                        opacity: 0.26,
                        animation: _liquidAnimation.value,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                _header(context),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF5B8CFF)))
                      : errorMessage != null
                      ? _buildErrorState()
                      : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    child: Column(
                      children: [
                        _buildProfileHeader(),
                        const SizedBox(height: 24),
                        _buildProfileForm(),
                        const SizedBox(height: 20),
                        _buildAccountSettings(),
                        const SizedBox(height: 20),
                        _buildDangerZone(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isSaving)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF5B8CFF)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withOpacity(0.1),
            ),
            child: const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          ),
          const SizedBox(height: 24),
          const Text(
            'Something went wrong',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage ?? 'Failed to load profile',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadProfileData,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B8CFF),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF5B8CFF), Color(0xFF9333EA)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5B8CFF).withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: CircleAvatar(
                  radius: 53,
                  backgroundColor: const Color(0xFF0B0F1A),
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: avatarUrl == null
                      ? Text(
                    fullName?.isNotEmpty == true
                        ? fullName![0].toUpperCase()
                        : email?[0].toUpperCase() ?? '?',
                    style: const TextStyle(fontSize: 40, color: Colors.white),
                  )
                      : null,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5B8CFF), Color(0xFF9333EA)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5B8CFF).withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF5B8CFF), Color(0xFF9333EA)],
          ).createShader(bounds),
          child: Text(
            fullName?.isNotEmpty == true ? fullName! : 'Add your name',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Text(
          email ?? '',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileForm() {
    return _GlassMorphismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5B8CFF), Color(0xFF9333EA)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_outline, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                "Profile Information",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              _AnimatedIconButton(
                onPressed: _showEditProfileBottomSheet,
                icon: Icons.edit,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            icon: Icons.badge_outlined,
            label: 'User ID',
            value: userId?.substring(0, 8) ?? 'N/A',
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.person_outline,
            label: 'Full Name',
            value: fullName ?? 'Not set',
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: email ?? '',
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: phoneNumber ?? 'Not set',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF5B8CFF)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSettings() {
    return _GlassMorphismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5B8CFF), Color(0xFF9333EA)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.settings_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                "Account Settings",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSettingTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update your password regularly',
            gradient: const [Color(0xFF5B8CFF), Color(0xFF9333EA)],
            onTap: _showChangePasswordBottomSheet,
          ),
          const Divider(color: Colors.white24, height: 24),
          _buildSettingTile(
            icon: Icons.logout,
            title: 'Sign Out',
            subtitle: 'Sign out from this device',
            gradient: const [Colors.orange, Colors.deepOrange],
            onTap: _signOut,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient.map((c) => c.withOpacity(0.2)).toList(),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: gradient,
                ).createShader(bounds),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return _GlassMorphismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.redAccent, Colors.orange],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                "Danger Zone",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Deleting your account is a permanent action and cannot be undone.",
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          _buildDangerTile(
            icon: Icons.delete_forever,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account and all data',
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }

  Widget _buildDangerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.withOpacity(0.1),
              Colors.red.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: Colors.redAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.redAccent,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.warning_amber_rounded, size: 20, color: Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              "Profile",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadProfileData,
          ),
        ],
      ),
    );
  }
}

class _LiquidBlob3D extends StatelessWidget {
  final double? width;
  final double? height;
  final double? size;
  final Color color;
  final double opacity;
  final double animation;

  const _LiquidBlob3D({
    this.width,
    this.height,
    this.size,
    required this.color,
    required this.opacity,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(animation * 0.1)
        ..rotateY(animation * 0.2),
      alignment: Alignment.center,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 140, sigmaY: 140),
        child: Container(
          width: size ?? width,
          height: size ?? height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: RadialGradient(
              colors: [
                color.withOpacity(opacity),
                color.withOpacity(opacity * 0.7),
                color.withOpacity(opacity * 0.3),
              ],
              stops: const [0.3, 0.6, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(opacity * 0.5),
                blurRadius: 100,
                spreadRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassMorphismCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? borderRadius;

  const _GlassMorphismCard({
    required this.child,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? 20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.2),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(borderRadius ?? 20),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AnimatedGlassButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const _AnimatedGlassButton({
    required this.onPressed,
    required this.child,
  });

  @override
  State<_AnimatedGlassButton> createState() => _AnimatedGlassButtonState();
}

class _AnimatedGlassButtonState extends State<_AnimatedGlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5B8CFF), Color(0xFF9333EA)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5B8CFF).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Center(child: widget.child),
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedIconButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;

  const _AnimatedIconButton({
    required this.onPressed,
    required this.icon,
  });

  @override
  State<_AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: 1 - (_controller.value * 0.1),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF5B8CFF).withOpacity(0.2),
                    const Color(0xFF9333EA).withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF5B8CFF), Color(0xFF9333EA)],
                ).createShader(bounds),
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}