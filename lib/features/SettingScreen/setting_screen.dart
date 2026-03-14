import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

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

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _saveThemePreference();
    notifyListeners();
  }

  Future<void> setTheme(bool isDark) async {
    if (_isDarkMode != isDark) {
      _isDarkMode = isDark;
      await _saveThemePreference();
      notifyListeners();
    }
  }

  Future<void> loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
    }
  }

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
// BIOMETRIC AUTH SERVICE
// ============================================================================

class BiometricAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> checkBiometricAvailability() async {
    try {
      final isAvailable = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting biometrics: $e');
      return [];
    }
  }

  static Future<bool> authenticateWithBiometrics() async {
    try {
      final isAvailable = await checkBiometricAvailability();
      if (!isAvailable) return false;

      final authenticated = await _auth.authenticate(
        localizedReason: 'Please authenticate to access your account',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      return authenticated;
    } catch (e) {
      debugPrint('Error during biometric authentication: $e');
      return false;
    }
  }
}

// ============================================================================
// DATABASE CONNECTION SERVICE
// ============================================================================

class DatabaseConnectionService {
  static const String _supabaseUrlKey = 'supabase_url';
  static const String _supabaseAnonKey = 'supabase_anon_key';

  static Future<bool> testConnection(String url, String anonKey) async {
    try {
      final client = SupabaseClient(url, anonKey);
      await client.from('settings').select('count').limit(1);
      return true;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }

  static Future<void> saveConnectionDetails(String url, String anonKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_supabaseUrlKey, url);
    await prefs.setString(_supabaseAnonKey, anonKey);
  }

  static Future<Map<String, String?>> loadConnectionDetails() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'url': prefs.getString(_supabaseUrlKey),
      'anonKey': prefs.getString(_supabaseAnonKey),
    };
  }

  static Future<void> reinitializeSupabase(String url, String anonKey) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}

// ============================================================================
// SETTINGS SERVICE - Manages settings in both SharedPreferences and Supabase
// ============================================================================

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Initialize settings table if it doesn't exist
  Future<void> initializeSettingsTable() async {
    try {
      // Check if settings table exists by trying to select from it
      await _supabase.from('settings').select('count').limit(1);
    } catch (e) {
      debugPrint('Settings table might not exist. Please create it manually: $e');
      // Note: Table creation should be done in Supabase dashboard or migrations
      // We'll handle this gracefully by returning default values
    }
  }

  // Load all settings from Supabase
  Future<Map<String, dynamic>> loadSettingsFromDB() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return {};

      final response = await _supabase
          .from('settings')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) {
        // Create default settings if none exist
        return await _createDefaultSettings(user.id);
      }

      return response;
    } catch (e) {
      debugPrint('Error loading settings from DB: $e');
      return {};
    }
  }

  // Create default settings
  Future<Map<String, dynamic>> _createDefaultSettings(String userId) async {
    final defaultSettings = {
      'user_id': userId,
      'currency': 'INR',
      'tax_rate': 18,
      'invoice_prefix': 'INV-',
      'profile_name': '',
      'profile_email': '',
      'profile_phone': '',
      'profile_address': '',
      'gstin': '',
      'profile_gstin': '',
      'bank_name': '',
      'bank_account': '',
      'bank_account_name': '',
      'bank_ifsc': '',
      'bank_swift': '',
      'bank_branch': 'Main Branch',
      'account_type': 'Current Account',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase.from('settings').insert(defaultSettings);
      return defaultSettings;
    } catch (e) {
      debugPrint('Error creating default settings: $e');
      return defaultSettings;
    }
  }

  // Save settings to Supabase
  Future<void> saveSettingsToDB(Map<String, dynamic> settings) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Ensure we have all required fields
      final settingsToSave = {
        ...settings,
        'user_id': user.id,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('settings')
          .upsert(settingsToSave);
    } catch (e) {
      debugPrint('Error saving settings to DB: $e');
    }
  }

  // Load all settings (combines DB and local settings)
  Future<Map<String, dynamic>> loadAllSettings() async {
    final Map<String, dynamic> allSettings = {};

    try {
      // Load from database
      final dbSettings = await loadSettingsFromDB();
      allSettings.addAll(dbSettings);

      // Load notification settings from SharedPreferences
      final notificationSettings = await loadNotificationSettings();
      allSettings['expenseAlerts'] = notificationSettings['expenseAlerts'];
      allSettings['promotions'] = notificationSettings['promotions'];

      // Load biometric setting
      allSettings['biometric'] = await loadBiometricSetting();

      // Load theme and language from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      allSettings['language'] = prefs.getString('language') ?? 'English';
      allSettings['isDarkMode'] = prefs.getBool('isDarkMode') ?? true;

      return allSettings;
    } catch (e) {
      debugPrint('Error loading all settings: $e');
      return {};
    }
  }

  // Save all settings
  Future<void> saveAllSettings(Map<String, dynamic> settings) async {
    try {
      // Save to database (only the fields that belong in DB)
      final dbSettings = Map<String, dynamic>.from(settings)
        ..remove('expenseAlerts')
        ..remove('promotions')
        ..remove('biometric')
        ..remove('language')
        ..remove('isDarkMode');

      if (dbSettings.isNotEmpty) {
        await saveSettingsToDB(dbSettings);
      }

      // Save notification settings
      if (settings.containsKey('expenseAlerts') || settings.containsKey('promotions')) {
        await saveNotificationSettings(
          expenseAlerts: settings['expenseAlerts'] ?? true,
          promotions: settings['promotions'] ?? false,
        );
      }

      // Save biometric setting
      if (settings.containsKey('biometric')) {
        await saveBiometricSetting(settings['biometric']);
      }

      // Save language
      if (settings.containsKey('language')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('language', settings['language']);
      }

      // Save theme
      if (settings.containsKey('isDarkMode')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isDarkMode', settings['isDarkMode']);
      }
    } catch (e) {
      debugPrint('Error saving all settings: $e');
    }
  }

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

  // Load currency from DB
  Future<String> loadCurrency() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 'INR';

      final response = await _supabase
          .from('settings')
          .select('currency')
          .eq('user_id', user.id)
          .maybeSingle();

      return response?['currency'] ?? 'INR';
    } catch (e) {
      debugPrint('Error loading currency: $e');
      return 'INR';
    }
  }

  // Save currency to DB
  Future<void> saveCurrency(String currency) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('settings')
          .upsert({
        'user_id': user.id,
        'currency': currency,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving currency: $e');
    }
  }

  // Load tax rate from DB
  Future<double> loadTaxRate() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 18.0;

      final response = await _supabase
          .from('settings')
          .select('tax_rate')
          .eq('user_id', user.id)
          .maybeSingle();

      return (response?['tax_rate'] ?? 18).toDouble();
    } catch (e) {
      debugPrint('Error loading tax rate: $e');
      return 18.0;
    }
  }

  // Save tax rate to DB
  Future<void> saveTaxRate(double taxRate) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('settings')
          .upsert({
        'user_id': user.id,
        'tax_rate': taxRate,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving tax rate: $e');
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
// BIOMETRIC SETUP DIALOG
// ============================================================================

class BiometricSetupDialog extends StatefulWidget {
  final Function(bool) onComplete;

  const BiometricSetupDialog({super.key, required this.onComplete});

  @override
  State<BiometricSetupDialog> createState() => _BiometricSetupDialogState();
}

class _BiometricSetupDialogState extends State<BiometricSetupDialog> {
  bool _isChecking = true;
  bool _isAvailable = false;
  List<BiometricType> _availableBiometrics = [];
  bool _isSettingUp = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    setState(() => _isChecking = true);

    _isAvailable = await BiometricAuthService.checkBiometricAvailability();
    if (_isAvailable) {
      _availableBiometrics = await BiometricAuthService.getAvailableBiometrics();
    }

    setState(() => _isChecking = false);
  }

  Future<void> _setupBiometric() async {
    setState(() => _isSettingUp = true);

    final authenticated = await BiometricAuthService.authenticateWithBiometrics();

    if (authenticated) {
      if (mounted) {
        widget.onComplete(true);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication enabled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      setState(() => _isSettingUp = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1A1F2E) : Colors.white,
      title: Text(
        'Biometric Authentication',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Container(
        width: 300,
        child: _isChecking
            ? const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),
        )
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isAvailable ? Icons.fingerprint : Icons.error_outline,
              size: 64,
              color: _isAvailable
                  ? const Color(0xFF5B8CFF)
                  : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _isAvailable
                  ? 'Your device supports biometric authentication'
                  : 'Biometric authentication is not available on this device',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            if (_isAvailable && _availableBiometrics.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Available: ${_availableBiometrics.map((b) => b.name).join(', ')}',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
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
        if (_isAvailable)
          ElevatedButton(
            onPressed: _isSettingUp ? null : _setupBiometric,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B8CFF),
            ),
            child: _isSettingUp
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Text('Enable'),
          ),
      ],
    );
  }
}

// ============================================================================
// DATABASE CONNECTION DIALOG
// ============================================================================

class DatabaseConnectionDialog extends StatefulWidget {
  final Function() onConnected;

  const DatabaseConnectionDialog({super.key, required this.onConnected});

  @override
  State<DatabaseConnectionDialog> createState() => _DatabaseConnectionDialogState();
}

class _DatabaseConnectionDialogState extends State<DatabaseConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _anonKeyController = TextEditingController();
  bool _isLoading = false;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _loadExistingConnection();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _anonKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingConnection() async {
    final details = await DatabaseConnectionService.loadConnectionDetails();
    setState(() {
      _urlController.text = details['url'] ?? '';
      _anonKeyController.text = details['anonKey'] ?? '';
    });
  }

  Future<void> _testAndSaveConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final url = _urlController.text.trim();
    final anonKey = _anonKeyController.text.trim();

    final isConnected = await DatabaseConnectionService.testConnection(url, anonKey);

    if (isConnected) {
      await DatabaseConnectionService.saveConnectionDetails(url, anonKey);
      await DatabaseConnectionService.reinitializeSupabase(url, anonKey);

      if (mounted) {
        widget.onConnected();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database connected successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to database. Please check your credentials.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1A1F2E) : Colors.white,
      title: Text(
        'Database Connection',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _urlController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Supabase URL',
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  hintText: 'https://your-project.supabase.co',
                  hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter Supabase URL';
                  }
                  if (!value.startsWith('https://')) {
                    return 'URL must start with https://';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _anonKeyController,
                obscureText: _obscureKey,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Anon Key',
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  hintText: 'eyJhbGciOiJIUzI1NiIs...',
                  hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
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
                      _obscureKey ? Icons.visibility_off : Icons.visibility,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter Anon Key';
                  }
                  return null;
                },
              ),
            ],
          ),
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
          onPressed: _isLoading ? null : _testAndSaveConnection,
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
              : const Text('Test & Connect'),
        ),
      ],
    );
  }
}

// ============================================================================
// INVOICE SETTINGS DIALOG
// ============================================================================

class InvoiceSettingsDialog extends StatefulWidget {
  final Map<String, dynamic> currentSettings;
  final Function(Map<String, dynamic>) onSave;

  const InvoiceSettingsDialog({
    super.key,
    required this.currentSettings,
    required this.onSave,
  });

  @override
  State<InvoiceSettingsDialog> createState() => _InvoiceSettingsDialogState();
}

class _InvoiceSettingsDialogState extends State<InvoiceSettingsDialog> {
  late TextEditingController _prefixController;
  late TextEditingController _profileNameController;
  late TextEditingController _profileEmailController;
  late TextEditingController _profilePhoneController;
  late TextEditingController _profileAddressController;
  late TextEditingController _gstinController;
  late TextEditingController _bankNameController;
  late TextEditingController _bankAccountController;
  late TextEditingController _bankAccountNameController;
  late TextEditingController _bankIfscController;
  late TextEditingController _bankSwiftController;
  late TextEditingController _bankBranchController;
  late TextEditingController _accountTypeController;
  late TextEditingController _currencyController;
  late TextEditingController _taxRateController;

  @override
  void initState() {
    super.initState();
    _prefixController = TextEditingController(text: widget.currentSettings['invoice_prefix'] ?? 'INV-');
    _profileNameController = TextEditingController(text: widget.currentSettings['profile_name'] ?? '');
    _profileEmailController = TextEditingController(text: widget.currentSettings['profile_email'] ?? '');
    _profilePhoneController = TextEditingController(text: widget.currentSettings['profile_phone'] ?? '');
    _profileAddressController = TextEditingController(text: widget.currentSettings['profile_address'] ?? '');
    _gstinController = TextEditingController(text: widget.currentSettings['gstin'] ?? '');
    _bankNameController = TextEditingController(text: widget.currentSettings['bank_name'] ?? '');
    _bankAccountController = TextEditingController(text: widget.currentSettings['bank_account'] ?? '');
    _bankAccountNameController = TextEditingController(text: widget.currentSettings['bank_account_name'] ?? '');
    _bankIfscController = TextEditingController(text: widget.currentSettings['bank_ifsc'] ?? '');
    _bankSwiftController = TextEditingController(text: widget.currentSettings['bank_swift'] ?? '');
    _bankBranchController = TextEditingController(text: widget.currentSettings['bank_branch'] ?? 'Main Branch');
    _accountTypeController = TextEditingController(text: widget.currentSettings['account_type'] ?? 'Current Account');
    _currencyController = TextEditingController(text: widget.currentSettings['currency'] ?? 'INR');
    _taxRateController = TextEditingController(text: widget.currentSettings['tax_rate']?.toString() ?? '18');
  }

  @override
  void dispose() {
    _prefixController.dispose();
    _profileNameController.dispose();
    _profileEmailController.dispose();
    _profilePhoneController.dispose();
    _profileAddressController.dispose();
    _gstinController.dispose();
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _bankAccountNameController.dispose();
    _bankIfscController.dispose();
    _bankSwiftController.dispose();
    _bankBranchController.dispose();
    _accountTypeController.dispose();
    _currencyController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final settings = {
      'invoice_prefix': _prefixController.text.trim(),
      'profile_name': _profileNameController.text.trim(),
      'profile_email': _profileEmailController.text.trim(),
      'profile_phone': _profilePhoneController.text.trim(),
      'profile_address': _profileAddressController.text.trim(),
      'gstin': _gstinController.text.trim(),
      'profile_gstin': _gstinController.text.trim(), // Alias for backward compatibility
      'bank_name': _bankNameController.text.trim(),
      'bank_account': _bankAccountController.text.trim(),
      'bank_account_name': _bankAccountNameController.text.trim(),
      'bank_ifsc': _bankIfscController.text.trim(),
      'bank_swift': _bankSwiftController.text.trim(),
      'bank_branch': _bankBranchController.text.trim(),
      'account_type': _accountTypeController.text.trim(),
      'currency': _currencyController.text.trim().toUpperCase(),
      'tax_rate': double.tryParse(_taxRateController.text.trim()) ?? 18.0,
    };
    widget.onSave(settings);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                ]
                    : [
                  Colors.white,
                  Colors.grey.shade50,
                ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.10)
                    : Colors.grey.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.10)
                            : Colors.grey.withOpacity(0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Invoice Settings',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Currency & Tax',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(isDark, 'Currency (e.g., INR, USD)', _currencyController),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTextField(isDark, 'Tax Rate (%)', _taxRateController, keyboardType: TextInputType.number),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'Invoice Prefix',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildTextField(isDark, 'Prefix (e.g., INV-)', _prefixController),
                        const SizedBox(height: 16),

                        Text(
                          'Company / Profile Information',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildTextField(isDark, 'Profile Name', _profileNameController),
                        const SizedBox(height: 8),
                        _buildTextField(isDark, 'Email', _profileEmailController),
                        const SizedBox(height: 8),
                        _buildTextField(isDark, 'Phone', _profilePhoneController),
                        const SizedBox(height: 8),
                        _buildTextField(isDark, 'Address', _profileAddressController, maxLines: 3),
                        const SizedBox(height: 8),
                        _buildTextField(isDark, 'GSTIN', _gstinController),
                        const SizedBox(height: 16),

                        Text(
                          'Bank Account Details',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildTextField(isDark, 'Bank Name', _bankNameController),
                        const SizedBox(height: 8),
                        _buildTextField(isDark, 'Account Name', _bankAccountNameController),
                        const SizedBox(height: 8),
                        _buildTextField(isDark, 'Account Number', _bankAccountController),
                        const SizedBox(height: 8),
                        _buildTextField(isDark, 'IFSC Code', _bankIfscController),
                        const SizedBox(height: 8),
                        _buildTextField(isDark, 'SWIFT Code', _bankSwiftController),
                        const SizedBox(height: 8),
                        _buildTextField(isDark, 'Branch', _bankBranchController),
                        const SizedBox(height: 8),
                        _buildTextField(isDark, 'Account Type', _accountTypeController),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.10)
                            : Colors.grey.withOpacity(0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B8CFF),
                        ),
                        child: const Text('Save Settings'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(bool isDark, String label, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
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
  Map<String, dynamic> dbSettings = {};

  // Services
  final themeProvider = ThemeProvider();
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
      // Initialize settings table if needed
      await settingsService.initializeSettingsTable();

      // Load all settings
      final allSettings = await settingsService.loadAllSettings();

      setState(() {
        // Database settings
        dbSettings = Map.from(allSettings)
          ..remove('expenseAlerts')
          ..remove('promotions')
          ..remove('biometric')
          ..remove('language')
          ..remove('isDarkMode');

        // Local settings
        expenseAlerts = allSettings['expenseAlerts'] ?? true;
        promotions = allSettings['promotions'] ?? false;
        biometric = allSettings['biometric'] ?? true;
        currentLanguage = allSettings['language'] ?? 'English';
        isDarkMode = allSettings['isDarkMode'] ?? true;

        // Update theme provider
        themeProvider.setTheme(isDarkMode);

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

    // Save to SharedPreferences
    await settingsService.saveNotificationSettings(
      expenseAlerts: expenseAlerts,
      promotions: promotions,
    );
  }

  Future<void> _togglePromotions(bool value) async {
    setState(() => promotions = value);

    // Save to SharedPreferences
    await settingsService.saveNotificationSettings(
      expenseAlerts: expenseAlerts,
      promotions: promotions,
    );
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Show biometric setup dialog
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => BiometricSetupDialog(
          onComplete: (success) {
            if (success) {
              setState(() => biometric = true);
              settingsService.saveBiometricSetting(true);
            }
          },
        ),
      );

      if (result != true) {
        setState(() => biometric = false);
      }
    } else {
      setState(() => biometric = false);
      await settingsService.saveBiometricSetting(false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication disabled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _toggleTheme(bool value) async {
    // Actually toggle the theme
    setState(() {
      isDarkMode = value;
    });

    await themeProvider.setTheme(value);

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);

    // Show confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Dark mode enabled' : 'Light mode enabled'),
          backgroundColor: const Color(0xFF5B8CFF),
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
      setState(() => currentLanguage = selected);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', selected);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Language changed to $selected'),
            backgroundColor: const Color(0xFF5B8CFF),
          ),
        );
      }
    }
  }

  Future<void> _showInvoiceSettings() async {
    await showDialog(
      context: context,
      builder: (context) => InvoiceSettingsDialog(
        currentSettings: dbSettings,
        onSave: (updatedSettings) async {
          setState(() {
            dbSettings.addAll(updatedSettings);
          });

          // Save to database
          await settingsService.saveSettingsToDB(updatedSettings);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invoice settings saved successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _showDatabaseConnectionDialog() async {
    await showDialog(
      context: context,
      builder: (context) => DatabaseConnectionDialog(
        onConnected: () {
          // Refresh settings after connection
          _initializeSettings();
        },
      ),
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
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF05060A) : const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // Background blobs
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
                  child: _isLoading
                      ? _buildLoading(isDark)
                      : SingleChildScrollView(
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
                          title: "Invoice Settings",
                          children: [
                            _row(
                              isDark: isDark,
                              icon: Icons.currency_rupee,
                              title: "Currency",
                              subtitle: dbSettings['currency'] ?? 'INR',
                              trailing: _buildActionButton(
                                isDark: isDark,
                                label: "Edit",
                                onTap: _showInvoiceSettings,
                              ),
                            ),
                            _divider(isDark),
                            _row(
                              isDark: isDark,
                              icon: Icons.percent,
                              title: "Tax Rate",
                              subtitle: "${dbSettings['tax_rate'] ?? 18}%",
                              trailing: _buildActionButton(
                                isDark: isDark,
                                label: "Edit",
                                onTap: _showInvoiceSettings,
                              ),
                            ),
                            _divider(isDark),
                            _row(
                              isDark: isDark,
                              icon: Icons.receipt_outlined,
                              title: "Invoice Prefix",
                              subtitle: dbSettings['invoice_prefix'] ?? 'INV-',
                              trailing: _buildActionButton(
                                isDark: isDark,
                                label: "Edit",
                                onTap: _showInvoiceSettings,
                              ),
                            ),
                            _divider(isDark),
                            _row(
                              isDark: isDark,
                              icon: Icons.business,
                              title: "Company Details",
                              subtitle: dbSettings['profile_name'] ?? 'Not set',
                              trailing: _buildActionButton(
                                isDark: isDark,
                                label: "Edit",
                                onTap: _showInvoiceSettings,
                              ),
                            ),
                            _divider(isDark),
                            _row(
                              isDark: isDark,
                              icon: Icons.account_balance,
                              title: "Bank Details",
                              subtitle: dbSettings['bank_name'] ?? 'Not set',
                              trailing: _buildActionButton(
                                isDark: isDark,
                                label: "Edit",
                                onTap: _showInvoiceSettings,
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
                          ],
                        ),

                        _section(
                          isDark: isDark,
                          title: "Advanced",
                          children: [
                            _row(
                              isDark: isDark,
                              icon: Icons.storage,
                              title: "Database Connection",
                              subtitle: "Configure Supabase connection",
                              trailing: _buildActionButton(
                                isDark: isDark,
                                label: "Configure",
                                onTap: _showDatabaseConnectionDialog,
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

  Widget _buildActionButton({
    required bool isDark,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF5B8CFF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF5B8CFF).withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5B8CFF),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
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