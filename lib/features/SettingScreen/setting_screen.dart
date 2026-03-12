import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// THEME PROVIDER - Manages app theme state
// ============================================================================

class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider _instance = ThemeProvider._internal();
  factory ThemeProvider() => _instance;
  ThemeProvider._internal();

  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  // Theme data
  ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF05060A),
    primaryColor: const Color(0xFF5B8CFF),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF5B8CFF),
      secondary: Color(0xFF9333EA),
      surface: Color(0xFF0B0F1A),
      background: Color(0xFF05060A),
      error: Color(0xFFEF4444),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    cardTheme: CardThemeData(
      color: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    dividerColor: Colors.white.withOpacity(0.1),
  );

  ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    primaryColor: const Color(0xFF5B8CFF),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF5B8CFF),
      secondary: Color(0xFF9333EA),
      surface: Colors.white,
      background: Color(0xFFF5F5F5),
      error: Color(0xFFEF4444),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 2,
      iconTheme: IconThemeData(color: Color(0xFF333333)),
      titleTextStyle: TextStyle(color: Color(0xFF333333), fontSize: 18, fontWeight: FontWeight.w600),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF333333)),
      bodyMedium: TextStyle(color: Color(0xFF666666)),
      titleLarge: TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.bold),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    dividerColor: Colors.grey.withOpacity(0.2),
  );

  ThemeData get currentTheme => _isDarkMode ? darkTheme : lightTheme;

  // Toggle theme
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _saveThemePreference();
    notifyListeners();
  }

  // Set theme
  Future<void> setTheme(bool isDark) async {
    if (_isDarkMode != isDark) {
      _isDarkMode = isDark;
      await _saveThemePreference();
      notifyListeners();
    }
  }

  // Load saved theme preference
  Future<void> loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
    }
  }

  // Save theme preference
  Future<void> _saveThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }
}

// ============================================================================
// LANGUAGE PROVIDER - Manages app language
// ============================================================================

class LanguageProvider extends ChangeNotifier {
  static final LanguageProvider _instance = LanguageProvider._internal();
  factory LanguageProvider() => _instance;
  LanguageProvider._internal();

  String _currentLanguage = 'English';
  String get currentLanguage => _currentLanguage;

  final Map<String, Locale> supportedLanguages = {
    'English': const Locale('en', 'US'),
    'Hindi': const Locale('hi', 'IN'),
    'Tamil': const Locale('ta', 'IN'),
    'Telugu': const Locale('te', 'IN'),
    'Kannada': const Locale('kn', 'IN'),
    'Malayalam': const Locale('ml', 'IN'),
  };

  Future<void> setLanguage(String language) async {
    if (supportedLanguages.containsKey(language)) {
      _currentLanguage = language;
      await _saveLanguagePreference();
      notifyListeners();
    }
  }

  Future<void> loadLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentLanguage = prefs.getString('language') ?? 'English';
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading language preference: $e');
    }
  }

  Future<void> _saveLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', _currentLanguage);
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
  }
}

// ============================================================================
// SETTINGS SERVICE - Manages all settings in SharedPreferences (no DB dependency)
// ============================================================================

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // Load notification settings from SharedPreferences
  Future<Map<String, bool>> loadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'expenseAlerts': prefs.getBool('expenseAlerts') ?? true,
        'promotions': prefs.getBool('promotions') ?? false,
      };
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
      return {'expenseAlerts': true, 'promotions': false};
    }
  }

  // Save notification settings to SharedPreferences
  Future<void> saveNotificationSettings({
    required bool expenseAlerts,
    required bool promotions,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('expenseAlerts', expenseAlerts);
      await prefs.setBool('promotions', promotions);
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
    }
  }

  // Load biometric setting from SharedPreferences
  Future<bool> loadBiometricSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('biometric') ?? true;
    } catch (e) {
      debugPrint('Error loading biometric setting: $e');
      return true;
    }
  }

  // Save biometric setting to SharedPreferences
  Future<void> saveBiometricSetting(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric', value);
    } catch (e) {
      debugPrint('Error saving biometric setting: $e');
    }
  }

  // Load all settings at once
  Future<Map<String, dynamic>> loadAllSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'expenseAlerts': prefs.getBool('expenseAlerts') ?? true,
        'promotions': prefs.getBool('promotions') ?? false,
        'biometric': prefs.getBool('biometric') ?? true,
        'language': prefs.getString('language') ?? 'English',
        'isDarkMode': prefs.getBool('isDarkMode') ?? true,
      };
    } catch (e) {
      debugPrint('Error loading all settings: $e');
      return {
        'expenseAlerts': true,
        'promotions': false,
        'biometric': true,
        'language': 'English',
        'isDarkMode': true,
      };
    }
  }
}

// ============================================================================
// LANGUAGE SELECTOR DIALOG
// ============================================================================

class LanguageSelectorDialog extends StatefulWidget {
  final String currentLanguage;
  final Function(String) onLanguageSelected;

  const LanguageSelectorDialog({
    super.key,
    required this.currentLanguage,
    required this.onLanguageSelected,
  });

  @override
  State<LanguageSelectorDialog> createState() => _LanguageSelectorDialogState();
}

class _LanguageSelectorDialogState extends State<LanguageSelectorDialog> {
  late String selectedLanguage;
  final List<Map<String, dynamic>> languages = [
    {'name': 'English', 'native': 'English', 'flag': '🇺🇸'},
    {'name': 'Hindi', 'native': 'हिन्दी', 'flag': '🇮🇳'},
    {'name': 'Tamil', 'native': 'தமிழ்', 'flag': '🇮🇳'},
    {'name': 'Telugu', 'native': 'తెలుగు', 'flag': '🇮🇳'},
    {'name': 'Kannada', 'native': 'ಕನ್ನಡ', 'flag': '🇮🇳'},
    {'name': 'Malayalam', 'native': 'മലയാളം', 'flag': '🇮🇳'},
  ];

  @override
  void initState() {
    super.initState();
    selectedLanguage = widget.currentLanguage;
  }

  @override
  Widget build(BuildContext context) {
    // Get theme from parent context instead of creating new instance
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1A1F2E) : Colors.white,
      title: Text(
        'Select Language',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Container(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: languages.length,
          itemBuilder: (context, index) {
            final lang = languages[index];
            final isSelected = lang['name'] == selectedLanguage;
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                leading: Text(
                  lang['flag'],
                  style: const TextStyle(fontSize: 24),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang['name'],
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    Text(
                      lang['native'],
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                selected: isSelected,
                selectedTileColor: isDark
                    ? const Color(0xFF5B8CFF).withOpacity(0.1)
                    : const Color(0xFF5B8CFF).withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: isSelected
                      ? BorderSide(
                    color: isDark
                        ? const Color(0xFF5B8CFF).withOpacity(0.5)
                        : const Color(0xFF5B8CFF),
                  )
                      : BorderSide.none,
                ),
                onTap: () {
                  setState(() {
                    selectedLanguage = lang['name'];
                  });
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onLanguageSelected(selectedLanguage);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5B8CFF),
          ),
          child: const Text('Select'),
        ),
      ],
    );
  }
}

// ============================================================================
// CHANGE PASSWORD DIALOG (Uses Supabase for actual password change)
// ============================================================================

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Get current user
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Update password
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1A1F2E) : Colors.white,
      title: Text(
        'Change Password',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _currentPasswordController,
              obscureText: _obscureCurrent,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: 'Current Password',
                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter current password';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew ? Icons.visibility_off : Icons.visibility,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter new password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm new password';
                }
                if (value != _newPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _changePassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5B8CFF),
          ),
          child: _isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : const Text('Change Password'),
        ),
      ],
    );
  }
}

// ============================================================================
// LOGOUT CONFIRMATION DIALOG
// ============================================================================

class LogoutDialog extends StatelessWidget {
  final VoidCallback onLogout;

  const LogoutDialog({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1A1F2E) : Colors.white,
      title: Text(
        'Logout',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Text(
        'Are you sure you want to logout?',
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onLogout();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('Logout'),
        ),
      ],
    );
  }
}

// ============================================================================
// MAIN SETTINGS SCREEN
// ============================================================================

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const SettingsScreen({super.key, this.onBack});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  static const double _headerHeight = 56;

  // Settings state
  bool expenseAlerts = true;
  bool promotions = false;
  bool biometric = true;
  String currentLanguage = 'English';
  bool isDarkMode = true;

  // Services
  final themeProvider = ThemeProvider();
  final languageProvider = LanguageProvider();
  final settingsService = SettingsService();

  // Loading state
  bool _isLoading = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    if (_isInitialized) return;

    setState(() => _isLoading = true);

    try {
      // Load all settings at once
      final settings = await settingsService.loadAllSettings();

      setState(() {
        expenseAlerts = settings['expenseAlerts'] as bool;
        promotions = settings['promotions'] as bool;
        biometric = settings['biometric'] as bool;
        currentLanguage = settings['language'] as String;
        isDarkMode = settings['isDarkMode'] as bool;

        // Update providers
        themeProvider.setTheme(isDarkMode);
        languageProvider.setLanguage(currentLanguage);

        _isLoading = false;
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleExpenseAlerts(bool value) async {
    setState(() => expenseAlerts = value);
    await settingsService.saveNotificationSettings(
      expenseAlerts: expenseAlerts,
      promotions: promotions,
    );
  }

  Future<void> _togglePromotions(bool value) async {
    setState(() => promotions = value);
    await settingsService.saveNotificationSettings(
      expenseAlerts: expenseAlerts,
      promotions: promotions,
    );
  }

  Future<void> _toggleBiometric(bool value) async {
    setState(() => biometric = value);
    await settingsService.saveBiometricSetting(value);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Biometric authentication enabled' : 'Biometric authentication disabled',
          ),
          backgroundColor: value ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleTheme(bool value) async {
    await themeProvider.setTheme(value);
    setState(() => isDarkMode = themeProvider.isDarkMode);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Dark mode enabled' : 'Light mode enabled',
          ),
          backgroundColor: const Color(0xFF5B8CFF),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showLanguageSelector() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => LanguageSelectorDialog(
        currentLanguage: currentLanguage,
        onLanguageSelected: (lang) {},
      ),
    );

    if (selected != null && selected != currentLanguage) {
      await languageProvider.setLanguage(selected);
      setState(() => currentLanguage = selected);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Language changed to $selected'),
            backgroundColor: const Color(0xFF5B8CFF),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _showChangePasswordDialog() async {
    // Check if user is logged in
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to change password'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await showDialog<bool>(
      context: context,
      builder: (context) => const ChangePasswordDialog(),
    );
  }

  Future<void> _showLogoutDialog() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => LogoutDialog(
        onLogout: () {},
      ),
    );

    if (shouldLogout == true) {
      _performLogout();
    }
  }

  Future<void> _performLogout() async {
    try {
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        // Navigate to login screen
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the current theme from provider
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF05060A) : const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // Background blobs (only in dark mode)
          if (isDark) ...[
            Positioned(
              top: -120,
              left: -100,
              child: _liquidBlob(
                width: 320,
                height: 420,
                color: const Color(0xFF9333EA),
                opacity: 0.28,
              ),
            ),
            Positioned(
              bottom: -160,
              right: -120,
              child: _liquidBlob(
                width: 380,
                height: 460,
                color: const Color(0xFF3B82F6),
                opacity: 0.26,
              ),
            ),
          ],

          SafeArea(
            child: Column(
              children: [
                _header(isDark),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    child: Column(
                      children: [
                        _section(
                          isDark: isDark,
                          title: "General",
                          children: [
                            _row(
                              isDark: isDark,
                              icon: isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                              title: "Theme",
                              subtitle: isDark ? "Dark Mode" : "Light Mode",
                              trailing: Switch(
                                value: isDark,
                                onChanged: _toggleTheme,
                                activeColor: const Color(0xFF5B8CFF),
                                activeTrackColor: const Color(0xFF5B8CFF).withOpacity(0.3),
                              ),
                            ),
                            _divider(isDark),
                            _row(
                              isDark: isDark,
                              icon: Icons.language,
                              title: "Language",
                              subtitle: currentLanguage,
                              trailing: GestureDetector(
                                onTap: _showLanguageSelector,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        currentLanguage,
                                        style: TextStyle(
                                          color: isDark ? Colors.white70 : Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.keyboard_arrow_down,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        _section(
                          isDark: isDark,
                          title: "Notifications",
                          children: [
                            _row(
                              isDark: isDark,
                              icon: Icons.notifications_none,
                              title: "Expense Alerts",
                              subtitle: "Get notified about large expenses",
                              trailing: Switch(
                                value: expenseAlerts,
                                onChanged: _toggleExpenseAlerts,
                                activeColor: const Color(0xFF5B8CFF),
                                activeTrackColor: const Color(0xFF5B8CFF).withOpacity(0.3),
                              ),
                            ),
                            _divider(isDark),
                            _row(
                              isDark: isDark,
                              icon: Icons.local_offer_outlined,
                              title: "Promotions",
                              subtitle: "Receive offers and updates",
                              trailing: Switch(
                                value: promotions,
                                onChanged: _togglePromotions,
                                activeColor: const Color(0xFF5B8CFF),
                                activeTrackColor: const Color(0xFF5B8CFF).withOpacity(0.3),
                              ),
                            ),
                          ],
                        ),

                        _section(
                          isDark: isDark,
                          title: "Security",
                          children: [
                            _row(
                              isDark: isDark,
                              icon: Icons.fingerprint,
                              title: "Biometric Authentication",
                              subtitle: "Use fingerprint/Face ID to log in",
                              trailing: Switch(
                                value: biometric,
                                onChanged: _toggleBiometric,
                                activeColor: const Color(0xFF5B8CFF),
                                activeTrackColor: const Color(0xFF5B8CFF).withOpacity(0.3),
                              ),
                            ),
                            _divider(isDark),
                            _row(
                              isDark: isDark,
                              icon: Icons.lock_outline,
                              title: "Change Password",
                              subtitle: "Update your password",
                              trailing: GestureDetector(
                                onTap: _showChangePasswordDialog,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5B8CFF).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFF5B8CFF).withOpacity(0.3),
                                    ),
                                  ),
                                  child: const Text(
                                    "Update",
                                    style: TextStyle(
                                      color: Color(0xFF5B8CFF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        _section(
                          isDark: isDark,
                          title: "Account",
                          children: [
                            _row(
                              isDark: isDark,
                              icon: Icons.logout,
                              iconColor: Colors.red,
                              title: "Logout",
                              subtitle: "Sign out from your account",
                              titleColor: Colors.red,
                              trailing: ElevatedButton(
                                onPressed: _showLogoutDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text("Logout"),
                              ),
                            ),
                          ],
                        ),

                        // App version
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Column(
                            children: [
                              Text(
                                'Hari Invoice v4.0.0',
                                style: TextStyle(
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '© 2025 All rights reserved',
                                style: TextStyle(
                                  color: isDark ? Colors.white24 : Colors.black26,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B8CFF)),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading settings...',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(bool isDark) {
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.12)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
          Expanded(
            child: Text(
              "Settings",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required bool isDark,
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _glassCard(
        isDark: isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    Color? iconColor,
    Color? titleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor ?? (isDark ? Colors.white70 : Colors.black54),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: titleColor ?? (isDark ? Colors.white : Colors.black87),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.grey.withOpacity(0.2),
        height: 1,
      ),
    );
  }

  Widget _glassCard({required bool isDark, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isDark
                ? Colors.transparent
                : Colors.white,
            gradient: isDark
                ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            )
                : null,
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.10)
                  : Colors.grey.withOpacity(0.2),
            ),
            boxShadow: isDark
                ? null
                : [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  static Widget _liquidBlob({
    required double width,
    required double height,
    required Color color,
    required double opacity,
  }) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 140, sigmaY: 140),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: color.withOpacity(opacity),
        ),
      ),
    );
  }
}