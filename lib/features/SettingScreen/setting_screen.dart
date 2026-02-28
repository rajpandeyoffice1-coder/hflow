import 'dart:ui';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const SettingsScreen({super.key, this.onBack});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const double _headerHeight = 56;

  bool expenseAlerts = true;
  bool promotions = false;
  bool biometric = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05060A),
      body: Stack(
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
          SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    child: Column(
                      children: [
                        _section(
                          title: "General",
                          children: [
                            _row(
                              icon: Icons.wb_sunny_outlined,
                              title: "Theme",
                              subtitle: "Light Mode",
                              trailing: Switch(
                                value: false,
                                onChanged: (_) {},
                                activeColor:
                                    const Color(0xFF5B8CFF),
                              ),
                            ),
                            _divider(),
                            _row(
                              icon: Icons.language,
                              title: "Language",
                              subtitle: "English",
                              trailing: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        _section(
                          title: "Notifications",
                          children: [
                            _row(
                              icon:
                                  Icons.notifications_none,
                              title: "Expense Alerts",
                              subtitle:
                                  "Get notified about large expenses",
                              trailing: Switch(
                                value: expenseAlerts,
                                onChanged: (v) => setState(
                                    () => expenseAlerts = v),
                                activeColor:
                                    const Color(0xFF5B8CFF),
                              ),
                            ),
                            _divider(),
                            _row(
                              icon:
                                  Icons.local_offer_outlined,
                              title: "Promotions",
                              subtitle:
                                  "Receive offers and updates",
                              trailing: Switch(
                                value: promotions,
                                onChanged: (v) => setState(
                                    () => promotions = v),
                                activeColor:
                                    const Color(0xFF5B8CFF),
                              ),
                            ),
                          ],
                        ),
                        _section(
                          title: "Security",
                          children: [
                            _row(
                              icon: Icons.fingerprint,
                              title:
                                  "Biometric Authentication",
                              subtitle:
                                  "Use fingerprint/Face ID to log in",
                              trailing: Switch(
                                value: biometric,
                                onChanged: (v) => setState(
                                    () => biometric = v),
                                activeColor:
                                    const Color(0xFF5B8CFF),
                              ),
                            ),
                            _divider(),
                            _row(
                              icon: Icons.lock_outline,
                              title: "Change Password",
                              subtitle: "Update",
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        _section(
                          title: "Account",
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.logout,
                                    color: Colors.red),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    "Logout",
                                    style: TextStyle(
                                      fontWeight:
                                          FontWeight.w600,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                                OutlinedButton(
                                  style:
                                      OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: Colors.red),
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(20),
                                    ),
                                  ),
                                  onPressed: () {},
                                  child: const Text(
                                    "Logout",
                                    style: TextStyle(
                                        color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ],
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

  Widget _header() {
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.12),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: Colors.white),
            onPressed: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
          const Expanded(
            child: Text(
              "Settings",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _glassCard(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white70,
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
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight:
                          FontWeight.w600,
                      color: Colors.white)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  Widget _divider() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 10),
      child: Divider(
        color: Colors.white.withOpacity(0.08),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter:
            ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color:
                  Colors.white.withOpacity(0.10),
            ),
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
      imageFilter:
          ImageFilter.blur(sigmaX: 140, sigmaY: 140),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(999),
          color: color.withOpacity(opacity),
        ),
      ),
    );
  }
}
