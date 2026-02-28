import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hflow/core/widgets/glass_bottom_nav.dart';
import 'package:hflow/core/widgets/glass_top_bar.dart';
import 'package:hflow/features/Portfolio/investment_portfolio_screen.dart';
import 'package:hflow/features/ProfileScreen/profile_screen.dart';
import 'package:hflow/features/SettingScreen/setting_screen.dart';
import 'package:hflow/features/ai_assistant/ai_assistant_screen.dart';
import 'package:hflow/features/expenses/expense_screen.dart';
import 'package:hflow/features/invoice/create_invoice.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const double _topBarHeight = 84;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        body: Stack(
          children: [
            _background(),

            Positioned(top: -80, left: -60, child: _blob(180)),
            Positioned(bottom: -100, right: -60, child: _blob(220)),
            if (_currentIndex == 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: _topBarHeight,
                  child: GlassTopBar(
                    leading: Image.asset(
                      'assets/images/logo_new.png',
                      height: 40,
                    ),
                    actions: [
                      const Icon(Icons.add),
                      const SizedBox(width: 14),
                      const Icon(Icons.notifications_none),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          );
                        },
                        child: const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFF5B8CFF),
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(
                top: _currentIndex == 0 ? _topBarHeight + 12 : 0,
              ),
              child: SafeArea(
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    _homeContent(),
                    ExpenseScreen(
                      onBack: () {
                        setState(() => _currentIndex = 0);
                      },
                    ),
                    AiAssistantScreen(),
                    InvestmentPortfolioScreen(
                      onBack: () {
                        setState(() => _currentIndex = 0);
                      },
                    ),
                    SettingsScreen(
                      onBack: () => setState(() => _currentIndex = 0),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: GlassBottomNav(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
        ),
      ),
    );
  }

  Widget _background() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEAF4FF), Color(0xFFF7F9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _homeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _balanceCard(),
          const SizedBox(height: 24),
          const Text(
            "Quick Actions",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _quickActions(context),
          const SizedBox(height: 28),
          const Text(
            "Monthly Spending Overview",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _chartCard(),
          const SizedBox(height: 28),
          const Text(
            "Budget Progress",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _budgetCard(
            title: "Food & Dining",
            amount: "₹1,200 Left",
            progress: 0.7,
            color: const Color(0xFFEF476F),
          ),
          const SizedBox(height: 12),
          _budgetCard(
            title: "Transportation",
            amount: "₹2,500 Left",
            progress: 0.3,
            color: const Color(0xFF118AB2),
          ),
        ],
      ),
    );
  }

  Widget _balanceCard() {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "₹2,35,789.50",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text("Total Balance", style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _Stat(
                icon: Icons.arrow_downward,
                label: "Income",
                value: "₹5,800.00",
                color: Colors.green,
              ),
              _Stat(
                icon: Icons.arrow_upward,
                label: "Expenses",
                value: "₹3,900.00",
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _GlassAction(
          icon: Icons.add,
          label: "Add Expense",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExpenseScreen()),
            );
          },
        ),
        _GlassAction(
          icon: Icons.receipt_long,
          label: "Invoice",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
            );
          },
        ),
        _GlassAction(
          icon: Icons.mic,
          label: "Voice AI",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _chartCard() {
    return _glass(
      child: SizedBox(
        height: 240,
        child: BarChart(
          BarChartData(
            maxY: 6000,
            gridData: FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    const months = [
                      'Jan',
                      'Feb',
                      'Mar',
                      'Apr',
                      'May',
                      'Jun',
                      'Jul',
                    ];
                    return Text(months[value.toInt()]);
                  },
                ),
              ),
            ),
            barGroups: List.generate(
              7,
              (i) => BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: [
                      4200,
                      4600,
                      4800,
                      5000,
                      5300,
                      4900,
                      5600,
                    ][i].toDouble(),
                    width: 8,
                    borderRadius: BorderRadius.circular(6),
                    color: const Color(0xFFEF6C4D),
                  ),
                  BarChartRodData(
                    toY: [
                      3000,
                      2800,
                      3100,
                      3500,
                      4000,
                      3300,
                      4200,
                    ][i].toDouble(),
                    width: 8,
                    borderRadius: BorderRadius.circular(6),
                    color: const Color(0xFF1AAE9F),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _budgetCard({
    required String title,
    required String amount,
    required double progress,
    required Color color,
  }) {
    return _glass(
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(amount, style: TextStyle(color: color)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              valueColor: AlwaysStoppedAnimation(color),
              backgroundColor: Colors.grey.shade200,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(String text) {
    return Center(child: Text(text, style: const TextStyle(fontSize: 20)));
  }

  Widget _glass({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _blob(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFBFD9FF), Color(0xFFE3ECFF)],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            Text(value, style: TextStyle(color: color)),
          ],
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Action({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF5B8CFF), size: 26),
        const SizedBox(height: 6),
        Text(label),
      ],
    );
  }
}
class _GlassAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GlassAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                height: 92,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF5B8CFF)
                            .withValues(alpha: 0.15),
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFF5B8CFF),
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
