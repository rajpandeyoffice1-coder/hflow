import 'dart:ui';
import 'package:flutter/material.dart';

class BudgetTrackingScreen extends StatelessWidget {
  const BudgetTrackingScreen({super.key});

  static const double _headerHeight = 56;

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
                _header(context),
                Expanded(
                  child: ListView(
                    padding:
                        const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    children: const [
                      _PeriodToggle(),
                      SizedBox(height: 20),
                      _BudgetCard(
                        icon: Icons.restaurant,
                        title: "Food & Dining",
                        spent: 550,
                        total: 600,
                      ),
                      _BudgetCard(
                        icon: Icons.home,
                        title: "Rent",
                        spent: 1200,
                        total: 1200,
                      ),
                      _BudgetCard(
                        icon: Icons.shopping_bag,
                        title: "Shopping",
                        spent: 320,
                        total: 300,
                      ),
                      _BudgetCard(
                        icon: Icons.directions_car,
                        title: "Transportation",
                        spent: 120,
                        total: 200,
                      ),
                      _BudgetCard(
                        icon: Icons.lightbulb_outline,
                        title: "Utilities",
                        spent: 100,
                        total: 150,
                      ),
                      _BudgetCard(
                        icon: Icons.movie_outlined,
                        title: "Entertainment",
                        spent: 40,
                        total: 100,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
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
              Navigator.of(context).maybePop();
            },
          ),
          const Expanded(
            child: Text(
              "Budget Tracking",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
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

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _GlassContainer(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _ToggleChip(label: "Monthly", active: true),
            _ToggleChip(label: "Weekly", active: false),
          ],
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;

  const _ToggleChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color:
            active ? const Color(0xFF5B8CFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:
              active ? Colors.white : Colors.white70,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final double spent;
  final double total;

  const _BudgetCard({
    required this.icon,
    required this.title,
    required this.spent,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (spent / total).clamp(0, 1);
    final isOver = spent > total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _GlassContainer(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 20,
                    color: Colors.white70),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  "${(spent / total * 100).round()}%",
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  "\$${spent.toStringAsFixed(2)}",
                  style: const TextStyle(
                      fontWeight:
                          FontWeight.w600,
                      color: Colors.white),
                ),
                const SizedBox(width: 6),
                Text(
                  "of \$${total.toStringAsFixed(2)}",
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: percent.toDouble(),
                minHeight: 6,
                backgroundColor:
                    Colors.white.withOpacity(0.08),
                valueColor:
                    AlwaysStoppedAnimation<Color>(
                  isOver
                      ? Colors.redAccent
                      : const Color(0xFF5B8CFF),
                ),
              ),
            ),
            if (isOver)
              const Padding(
                padding:
                    EdgeInsets.only(top: 6),
                child: Text(
                  "Over Budget",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.redAccent,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const _GlassContainer({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter:
            ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding:
              padding ?? const EdgeInsets.all(16),
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
}
