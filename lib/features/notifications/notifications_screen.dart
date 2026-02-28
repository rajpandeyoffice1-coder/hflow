import 'dart:ui';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool expenseAlerts = true;
  bool investmentUpdates = true;
  bool billReminders = false;
  bool transactionAlerts = true;
  bool promotionalOffers = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          "Notifications",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle("Recent Notifications"),

          _GlassNotificationCard(
            icon: Icons.shopping_cart_outlined,
            title: "Over budget: Groceries",
            subtitle:
                "You've spent 85% of your grocery budget for October.",
            tag: "Expense Alert",
            tagColor: Colors.redAccent,
            time: "Just now",
          ),

          _GlassNotificationCard(
            icon: Icons.trending_up,
            title: "Portfolio Up",
            subtitle: "Your investment portfolio increased by 1.2% today.",
            tag: "Investment Update",
            tagColor: Colors.green,
            time: "2 hours ago",
          ),

          _GlassNotificationCard(
            icon: Icons.receipt_long,
            title: "Electricity Bill Due",
            subtitle: "Your electricity bill of ₹2,500 is due in 3 days.",
            tag: "Bill Reminder",
            tagColor: Colors.orange,
            time: "Yesterday",
          ),

          _GlassNotificationCard(
            icon: Icons.swap_horiz,
            title: "New Transaction Alert",
            subtitle: "₹500 for coffee at Café Deluxe.",
            tag: "Transaction",
            tagColor: Colors.blue,
            time: "Oct 23",
          ),

          const SizedBox(height: 28),
          const _SectionTitle("Notification Settings"),

          _GlassToggleTile(
            title: "Expense Alerts",
            subtitle: "Receive notifications when you approach budget limits.",
            value: expenseAlerts,
            onChanged: (v) => setState(() => expenseAlerts = v),
          ),

          _GlassToggleTile(
            title: "Investment Updates",
            subtitle: "Get real-time alerts on your portfolio performance.",
            value: investmentUpdates,
            onChanged: (v) => setState(() => investmentUpdates = v),
          ),

          _GlassToggleTile(
            title: "Bill Reminders",
            subtitle: "Never miss a due date for your upcoming bills.",
            value: billReminders,
            onChanged: (v) => setState(() => billReminders = v),
          ),

          _GlassToggleTile(
            title: "Transaction Alerts",
            subtitle: "Alerts for all debit and credit transactions.",
            value: transactionAlerts,
            onChanged: (v) => setState(() => transactionAlerts = v),
          ),

          _GlassToggleTile(
            title: "Promotional Offers",
            subtitle: "Receive updates on new features and exclusive offers.",
            value: promotionalOffers,
            onChanged: (v) => setState(() => promotionalOffers = v),
          ),
        ],
      ),
    );
  }
}

/* ---------- Glass Components ---------- */

class _GlassNotificationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;
  final Color tagColor;
  final String time;

  const _GlassNotificationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.tagColor,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _GlassContainer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: tagColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tag,
                    style: TextStyle(
                      fontSize: 12,
                      color: tagColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _GlassToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _GlassToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _GlassContainer(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF5B8CFF),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;

  const _GlassContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    );
  }
}
