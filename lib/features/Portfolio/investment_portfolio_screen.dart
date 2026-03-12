// lib/screens/investment/investment_portfolio_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'investment_provider.dart';
import 'package:provider/provider.dart';
import '../../models/investment_models.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/liquid_blob.dart';
import 'add_investment_modal.dart';
import 'redemption_modal.dart';
import 'investment_detail_modal.dart';

class InvestmentPortfolioScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const InvestmentPortfolioScreen({super.key, this.onBack});

  @override
  State<InvestmentPortfolioScreen> createState() =>
      _InvestmentPortfolioScreenState();
}

class _InvestmentPortfolioScreenState extends State<InvestmentPortfolioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late InvestmentProvider _provider;
  
  String _selectedOwner = 'all';
  String _searchQuery = '';
  int _itemsPerPage = 20;
  String _selectedCategory = 'all';
  String _selectedDateRange = 'all';
  
  final TextEditingController _searchController = TextEditingController();
  
  // View mode: 'cards', 'table', 'calendar'
  String _currentView = 'cards';

  String _heatmapRange = "3m";
  DateTimeRange? _customRange;
  
  // Calendar state
  DateTime _calendarCurrentMonth = DateTime.now();
  
  // Selected investments for bulk actions
  final Set<String> _selectedInvestmentIds = {};

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = context.read<InvestmentProvider>();
      _loadData();
    });
  }

  Future<void> _loadData() async {
    await _provider.loadInitialData();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05060A),
      body: Stack(
        children: [
          const LiquidBlobBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildOwnerSelector(),
                _buildSummaryCards(),
                _buildTabBar(),
                Expanded(
                  child: Consumer<InvestmentProvider>(
                    builder: (context, provider, child) {
                      if (provider.isLoading) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF5B8CFF),
                          ),
                        );
                      }

                      return TabBarView(
                        controller: _tabController,
                        children: [
                          _buildDashboardTab(provider),
                          _buildInvestmentsTab(provider),
                          _buildAnalyticsTab(provider),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (context.watch<InvestmentProvider>().isRefreshing)
            _buildRefreshingIndicator(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "invPortFAB",
        onPressed: () => _showAddInvestmentModal(),
        backgroundColor: const Color(0xFF5B8CFF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    final provider = Provider.of<InvestmentProvider>(context);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Colors.white,
            ),
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
              "💎 Family Wealth",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),

          IconButton(
            icon: Icon(
              Icons.refresh,
              color: provider.isRefreshing
                  ? const Color(0xFF5B8CFF)
                  : Colors.white,
            ),
            onPressed: provider.isRefreshing
                ? null
                : () => provider.refreshData(),
          ),

          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _showMoreOptions,
          ),
        ],
      ),
    );
  }



  Widget _buildOwnerSelector() {
    double hariTotal = _provider.getTotalByOwner('Hari');
    double sangeethaTotal = _provider.getTotalByOwner('Sangeetha');
    double total = hariTotal + sangeethaTotal;
    double hariPercentage = total > 0 ? (hariTotal / total * 100) : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildOwnerChip('All', 'all', Icons.group),
                  const SizedBox(width: 8),
                  _buildOwnerChip('Hari', 'Hari', Icons.person),
                  const SizedBox(width: 8),
                  _buildOwnerChip('Sangeetha', 'Sangeetha', Icons.person_outline),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Text(
                  '${hariPercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFF5B8CFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  '/',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                Text(
                  '${(100 - hariPercentage).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerChip(String label, String value, IconData icon) {
    bool isSelected = _selectedOwner == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedOwner = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF5B8CFF)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    double totalInvested = _provider.getTotalInvested(owner: _selectedOwner);
    double totalCurrent = _provider.getTotalCurrentValue(owner: _selectedOwner);
    double totalRedeemed = _provider.getTotalRedeemed(owner: _selectedOwner);
    double totalProjected = _provider.getTotalProjected(owner: _selectedOwner);
    double growthPercent = totalInvested > 0 
        ? ((totalCurrent - totalInvested) / totalInvested * 100) 
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Current \nWealth',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: growthPercent >= 0 
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              growthPercent >= 0 
                                  ? Icons.trending_up 
                                  : Icons.trending_down,
                              color: growthPercent >= 0 
                                  ? Colors.green 
                                  : Colors.red,
                              size: 10,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${growthPercent.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: growthPercent >= 0 
                                    ? Colors.green 
                                    : Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_formatNumber(totalCurrent)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Invested: ₹${_formatNumber(totalInvested)}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Projected \n(5Y)',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_formatNumber(totalProjected)}',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Redeemed: ₹${_formatNumber(totalRedeemed)}',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(30),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          overlayColor: MaterialStateProperty.all(Colors.transparent),
          labelPadding: EdgeInsets.zero,
          indicator: BoxDecoration(
            color: const Color(0xFF5B8CFF),
            borderRadius: BorderRadius.circular(30),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Investments'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab(InvestmentProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeatmap(provider),
          const SizedBox(height: 20),
          _buildFinancialGoals(provider),
          const SizedBox(height: 20),
          _buildPortfolioDistribution(provider),
          const SizedBox(height: 20),
          _buildMonthlyTrend(provider),
          const SizedBox(height: 20),
          _buildFundDistribution(provider),
          const SizedBox(height: 20),
          _buildFamilyDistribution(provider),
        ],
      ),
    );
  }

  Widget _buildHeatmap(InvestmentProvider provider) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '🔥 Investment Intensity',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const Spacer(),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButton<String>(
                  value: _heatmapRange,
                  dropdownColor: const Color(0xFF1A1F2E),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  items: const [

                    DropdownMenuItem(
                      value: "3m",
                      child: Text("3 Months", style: TextStyle(color: Colors.white)),
                    ),

                    DropdownMenuItem(
                      value: "6m",
                      child: Text("6 Months", style: TextStyle(color: Colors.white)),
                    ),

                    DropdownMenuItem(
                      value: "12m",
                      child: Text("12 Months", style: TextStyle(color: Colors.white)),
                    ),

                    DropdownMenuItem(
                      value: "custom",
                      child: Text("Custom", style: TextStyle(color: Colors.white)),
                    ),

                  ],
                  onChanged: (value) async {

                    if (value == "custom") {

                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );

                      if (range != null) {
                        setState(() {
                          _customRange = range;
                          _heatmapRange = value!;
                        });
                      }

                    } else {
                      setState(() {
                        _heatmapRange = value!;
                      });
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: _buildHeatmapGrid(provider),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'Less',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(width: 6),
              _buildHeatmapLegendItem(0.1),
              _buildHeatmapLegendItem(0.3),
              _buildHeatmapLegendItem(0.5),
              _buildHeatmapLegendItem(0.7),
              _buildHeatmapLegendItem(1.0),
              const SizedBox(width: 6),
              const Text(
                'More',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapGrid(InvestmentProvider provider) {

    final heatmapData = provider.getHeatmapData();
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 365));

    List<Widget> weeks = [];

    for (int week = 0; week < 52; week++) {

      List<Widget> days = [];

      for (int day = 0; day < 7; day++) {

        final date = startDate.add(Duration(days: week * 7 + day));

        final amount =
            heatmapData[DateFormat('yyyy-MM-dd').format(date)] ?? 0;

        double intensity = 0;

        if (amount > 0) {
          intensity = (amount / 100000).clamp(0.1, 1.0);
        }

        days.add(
          GestureDetector(
            onTap: () => _showDayDetails(date, amount),
            child: Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Color.lerp(
                  Colors.white.withOpacity(0.05),
                  const Color(0xFF5B8CFF),
                  intensity,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }

      weeks.add(Column(children: days));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: weeks),
    );
  }

  Widget _buildHeatmapLegendItem(double opacity) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: Color.lerp(
          Colors.white.withOpacity(0.05),
          const Color(0xFF5B8CFF),
          opacity,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildFinancialGoals(InvestmentProvider provider) {
    final goals = provider.financialGoals;
    
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🎯 Financial Goals',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: _showAddGoalModal,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                ),
                child: const Text(
                  '+ Add Goal',
                  style: TextStyle(
                    color: Color(0xFF5B8CFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (goals.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      '🎯',
                      style: TextStyle(fontSize: 32),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No goals set yet',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _showAddGoalModal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B8CFF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Create Goal',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...goals.map((goal) => _buildGoalItem(goal, provider)),
        ],
      ),
    );
  }

  Widget _buildGoalProgress(InvestmentProvider provider) {

    final goalTotals = provider.calculateGoalInvestments();

    return Column(
      children: provider.financialGoals.map((goal) {

        final invested = goalTotals[goal.id] ?? 0;

        final progress = invested / goal.targetAmount;

        return Card(
          child: ListTile(
            title: Text(goal.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: progress),
                Text(
                  "₹${invested.toStringAsFixed(0)} / ₹${goal.targetAmount.toStringAsFixed(0)}",
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  List<PieChartSectionData> buildPieSections(
      Map<int, double> totals,
      List<Category> categories,
      ) {

    List<PieChartSectionData> sections = [];

    totals.forEach((categoryId, amount) {

      final category =
      categories.firstWhere((c) => c.id == categoryId);

      sections.add(
        PieChartSectionData(
          value: amount,
          title: category.name,
        ),
      );
    });

    return sections;
  }

  Widget _buildCategoryPie(InvestmentProvider provider) {

    final totals = provider.calculateCategoryTotals();

    final sections =
    buildPieSections(totals, provider.categories);

    return PieChart(
      PieChartData(
        sections: sections,
      ),
    );
  }

  Widget _buildGoalItem(FinancialGoal goal, InvestmentProvider provider){
    final provider = Provider.of<InvestmentProvider>(context, listen:false);

    final goalTotals = provider.calculateGoalInvestments();

    final invested = goalTotals[goal.id] ?? 0;

    double progress = invested / goal.targetAmount;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(int.parse(goal.color.replaceFirst('#', '0xFF'))),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    goal.icon,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (goal.deadline != null)
                      Text(
                        'Due ${DateFormat('dd MMM yyyy').format(goal.deadline!)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(int.parse(goal.color.replaceFirst('#', '0xFF')))
                            .withOpacity(0.7),
                        Color(int.parse(goal.color.replaceFirst('#', '0xFF'))),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${_formatNumber(invested)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
              Text(
                '₹${_formatNumber(goal.targetAmount)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioDistribution(InvestmentProvider provider) {
    final distribution = provider.getCategoryDistribution(owner: _selectedOwner);
    print(provider.getCategoryDistribution());
    if (distribution.isEmpty) {
      return GlassCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'No investments to display',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ),
      );
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Portfolio Distribution',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: distribution.entries.map((entry) {
                  return PieChartSectionData(
                    value: entry.value,
                    title: '',
                    color: provider.getCategoryColor(entry.key),
                    radius: 80,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: distribution.entries.map((entry) {
              return _buildLegendItem(
                entry.key,
                provider.getCategoryColor(entry.key),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrend(InvestmentProvider provider) {
    final monthlyData = provider.getMonthlyTrend(owner: _selectedOwner);
    
    if (monthlyData.isEmpty) {
      return GlassCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'No monthly data',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ),
      );
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Investment Trend',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Last 12 Months',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: monthlyData.values.isNotEmpty
                    ? monthlyData.values.reduce((a, b) => a > b ? a : b) * 1.2
                    : 100000,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final keys = monthlyData.keys.toList();
                        if (value.toInt() >= 0 &&
                            value.toInt() < keys.length) {
                          return Text(
                            keys[value.toInt()].substring(0, 3),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(monthlyData.length, (index) {
                  final value = monthlyData.values.toList()[index];
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: value,
                        color: const Color(0xFF5B8CFF),
                        width: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFundDistribution(InvestmentProvider provider) {
    final distribution = provider.getCategoryDistribution(owner: _selectedOwner);
    final total = distribution.values.fold(0.0, (a, b) => a + b);

    if (distribution.isEmpty) {
      return GlassCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'No investments to display',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ),
      );
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fund Distribution by Category',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'See how your investments are spread across different funds',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          ...distribution.entries.take(5).map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Spacer(),
                      Text(
                        '₹${_formatNumber(entry.value)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: (entry.value / total).toDouble(),
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      provider.getCategoryColor(entry.key),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFamilyDistribution(InvestmentProvider provider) {
    double hariTotal = provider.getTotalCurrentValue(owner: 'Hari');
    double sangeethaTotal = provider.getTotalCurrentValue(owner: 'Sangeetha');
    double total = hariTotal + sangeethaTotal;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Family Fund Distribution',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            "Compare Hari's and Sangeetha's investments across each fund",
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildFamilyProgress(
                  'HARI',
                  hariTotal,
                  total,
                  const Color(0xFF5B8CFF),
                  Icons.person,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFamilyProgress(
                  'SANGEETHA',
                  sangeethaTotal,
                  total,
                  const Color(0xFF10B981),
                  Icons.person_outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyProgress(
    String name,
    double value,
    double total,
    Color color,
    IconData icon,
  ) {
    double percentage = total > 0 ? (value / total * 100) : 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage / 100,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_formatNumber(value)}',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentsTab(InvestmentProvider provider) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          _buildSearchAndFilterBar(),
          _buildViewToggle(),
          if (_selectedInvestmentIds.isNotEmpty) _buildBulkActionsBar(),
          _buildPaginationControls(),
          _buildInvestmentList(provider),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [

          /// SEARCH
          SizedBox(
            width: 260,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '🔍 Search investments...',
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon: Icon(Icons.search, color: Colors.white54),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          ),

          /// CATEGORY
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<String>(
              value: _selectedCategory,
              dropdownColor: const Color(0xFF1A1F2E),
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: Text('All Categories',
                      style: TextStyle(color: Colors.white)),
                ),
                ..._provider.categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat.name,
                    child: Text('${cat.icon} ${cat.name}',
                        style: const TextStyle(color: Colors.white)),
                  );
                }),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
            ),
          ),

          /// DATE RANGE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<String>(
              value: _selectedDateRange,
              dropdownColor: const Color(0xFF1A1F2E),
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('All Time',
                      style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: 'this-month',
                  child: Text('This Month',
                      style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: 'last-3-months',
                  child: Text('Last 3 Months',
                      style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: 'last-6-months',
                  child: Text('Last 6 Months',
                      style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: 'this-year',
                  child: Text('This Year',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedDateRange = value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  _buildViewToggleButton('cards', Icons.grid_view),
                  _buildViewToggleButton('table', Icons.table_rows),
                  _buildViewToggleButton('calendar', Icons.calendar_month),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggleButton(String view, IconData icon) {
    bool isSelected = _currentView == view;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentView = view),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF5B8CFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Center(
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulkActionsBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Text(
              '${_selectedInvestmentIds.length} selected',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _showBulkDeleteConfirmation,
              icon: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 16),
              label: const Text(
                'Delete Selected',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => setState(() => _selectedInvestmentIds.clear()),
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    final filteredCount = _getFilteredInvestments().length;
    final pageCount = (filteredCount / _itemsPerPage).ceil();
    final currentPage = 0; // You'll need to track current page

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 8,
        children: [
          Row(
            children: [
              const Text(
                'Items per page:',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<int>(
                  value: _itemsPerPage,
                  dropdownColor: const Color(0xFF1A1F2E),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  items: [10, 20, 50, 100].map((value) {
                    return DropdownMenuItem(
                      value: value,
                      child: Text(
                        '$value',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _itemsPerPage = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Showing $filteredCount items',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white54),
                onPressed: currentPage > 0 ? () {} : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Page ${currentPage + 1} of $pageCount',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white54),
                onPressed: currentPage < pageCount - 1 ? () {} : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentList(InvestmentProvider provider) {
    final filtered = _getFilteredInvestments();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
                child: const Icon(
                  Icons.trending_up,
                  size: 48,
                  color: Colors.white24,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No investments found',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Start tracking your investments to see them here',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _showAddInvestmentModal,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Add Investment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B8CFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentView == 'cards') {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          return _buildInvestmentCard(filtered[index]);
        },
      );
    } else if (_currentView == 'table') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _buildInvestmentTable(filtered),
        ),
      );
    } else {
      return _buildCalendarView(provider);
    }
  }

  Widget _buildInvestmentCard(Investment inv) {
    return GestureDetector(
      onTap: () => _showInvestmentDetails(inv),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _provider.getCategoryColor(inv.category).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      _provider.getCategoryIcon(inv.category),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const Spacer(),
                Checkbox(
                  value: _selectedInvestmentIds.contains(inv.id),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedInvestmentIds.add(inv.id);
                      } else {
                        _selectedInvestmentIds.remove(inv.id);
                      }
                    });
                  },
                  fillColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.selected)) {
                      return const Color(0xFF5B8CFF);
                    }
                    return Colors.white.withOpacity(0.1);
                  }),
                  checkColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              inv.category,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (inv.subCategory != null)
              Text(
                inv.subCategory!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),
            Text(
              '₹${_formatNumber(inv.amount)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: inv.owner == 'Hari'
                        ? const Color(0xFF5B8CFF).withOpacity(0.2)
                        : const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    inv.owner,
                    style: TextStyle(
                      color: inv.owner == 'Hari'
                          ? const Color(0xFF5B8CFF)
                          : const Color(0xFF10B981),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd MMM').format(DateTime.parse(inv.date)),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvestmentTable(List<Investment> investments) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 24,
        headingRowHeight: 48,
        dataRowHeight: 60,
        headingTextStyle: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        dataTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
        columns: const [
          DataColumn(label: Text('')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Sub Category')),
          DataColumn(label: Text('Owner')),
          DataColumn(label: Text('Amount')),
          DataColumn(label: Text('Comments')),
          DataColumn(label: Text('Actions')),
        ],
        rows: investments.map((inv) {
          return DataRow(
            cells: [
              DataCell(
                Checkbox(
                  value: _selectedInvestmentIds.contains(inv.id),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedInvestmentIds.add(inv.id);
                      } else {
                        _selectedInvestmentIds.remove(inv.id);
                      }
                    });
                  },
                  fillColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.selected)) {
                      return const Color(0xFF5B8CFF);
                    }
                    return Colors.white.withOpacity(0.1);
                  }),
                ),
              ),

              DataCell(
                Text(DateFormat('dd MMM yyyy').format(DateTime.parse(inv.date))),
              ),

              DataCell(
                Row(
                  children: [
                    Text(_provider.getCategoryIcon(inv.category)),
                    const SizedBox(width: 6),
                    Text(inv.category),
                  ],
                ),
              ),

              DataCell(Text(inv.subCategory ?? '-')),

              DataCell(
                Text(
                  inv.owner,
                  style: TextStyle(
                    color: inv.owner == 'Hari'
                        ? const Color(0xFF5B8CFF)
                        : const Color(0xFF10B981),
                  ),
                ),
              ),

              DataCell(
                Text(
                  '₹${_formatNumber(inv.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),

              DataCell(Text(inv.comments.isNotEmpty ? inv.comments : '-')),

              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, color: Colors.white70),
                      onPressed: () => _showInvestmentDetails(inv),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFF5B8CFF)),
                      onPressed: () => _showEditInvestmentModal(inv),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Color(0xFFEF4444)),
                      onPressed: () => _showDeleteConfirmation(inv),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? Colors.white,
          fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTableActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color color = Colors.white70,
  }) {
    return IconButton(
      icon: Icon(icon, color: color, size: 18),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildCalendarView(InvestmentProvider provider) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _calendarCurrentMonth = DateTime(
                      _calendarCurrentMonth.year,
                      _calendarCurrentMonth.month - 1,
                      1,
                    );
                  });
                },
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(_calendarCurrentMonth),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _calendarCurrentMonth = DateTime(
                      _calendarCurrentMonth.year,
                      _calendarCurrentMonth.month + 1,
                      1,
                    );
                  });
                },
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _calendarCurrentMonth = DateTime.now();
                  });
                },
                child: const Text(
                  'Today',
                  style: TextStyle(color: Color(0xFF5B8CFF)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCalendarGrid(provider),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(InvestmentProvider provider) {
    final daysInMonth = DateTime(
      _calendarCurrentMonth.year,
      _calendarCurrentMonth.month + 1,
      0,
    ).day;
    
    final firstDayOfMonth = DateTime(
      _calendarCurrentMonth.year,
      _calendarCurrentMonth.month,
      1,
    );
    
    final startingWeekday = firstDayOfMonth.weekday;
    
    final monthInvestments = provider.investments.where((inv) {
      final date = DateTime.parse(inv.date);
      return date.year == _calendarCurrentMonth.year &&
          date.month == _calendarCurrentMonth.month;
    }).toList();

    double totalMonth = monthInvestments.fold(0.0, (sum, inv) => sum + inv.amount);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Total',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '₹${_formatNumber(totalMonth)}',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Investment Days',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '${monthInvestments.length}',
                      style: const TextStyle(
                        color: Color(0xFF5B8CFF),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final day = index - startingWeekday + 2;
              
              if (day < 1 || day > daysInMonth) {
                return Container();
              }
              
              final date = DateTime(
                _calendarCurrentMonth.year,
                _calendarCurrentMonth.month,
                day,
              );
              
              final dayInvestments = monthInvestments.where((inv) {
                final invDate = DateTime.parse(inv.date);
                return invDate.day == day;
              }).toList();
              
              final hasInvestment = dayInvestments.isNotEmpty;
              final totalDayAmount = dayInvestments.fold(0.0, (double sum, inv) => sum + inv.amount);
              
              return GestureDetector(
                onTap: hasInvestment ? () => _showDayDetails(date, totalDayAmount) : null,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: hasInvestment
                        ? const Color(0xFF5B8CFF).withOpacity(0.2)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    border: hasInvestment
                        ? Border.all(color: const Color(0xFF5B8CFF).withOpacity(0.5))
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          color: hasInvestment ? Colors.white : Colors.white54,
                          fontWeight: hasInvestment ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (hasInvestment)
                        Text(
                          '₹${_formatCompactNumber(totalDayAmount)}',
                          style: const TextStyle(
                            color: Color(0xFF5B8CFF),
                            fontSize: 8,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(InvestmentProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAnalyticsHeader(),
          const SizedBox(height: 20),
          _buildPortfolioChart(provider),
          const SizedBox(height: 20),
          _buildGrowthProjection(provider),
          const SizedBox(height: 20),
          _buildSubcategoryDistribution(provider),
          const SizedBox(height: 20),
          _buildOwnerFundMatrix(provider),
        ],
      ),
    );
  }

  Widget _buildAnalyticsHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📊 Portfolio Analytics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Comprehensive insights and performance metrics',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: _selectedOwner,
            dropdownColor: const Color(0xFF1A1F2E),
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('All', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: 'Hari',
                child: Text('Hari', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: 'Sangeetha',
                child: Text('Sangeetha', style: TextStyle(color: Colors.white)),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedOwner = value);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPortfolioChart(InvestmentProvider provider) {
    final distribution = provider.getCategoryDistribution(owner: _selectedOwner);
    
    if (distribution.isEmpty) {
      return GlassCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'No data available',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ),
      );
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Portfolio Distribution',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 60,
                sections: distribution.entries.map((entry) {
                  return PieChartSectionData(
                    value: entry.value,
                    title: '${(entry.value / distribution.values.fold(0, (a, b) => a + b) * 100).toStringAsFixed(1)}%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    color: provider.getCategoryColor(entry.key),
                    radius: 100,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: distribution.entries.map((entry) {
              return _buildLegendItem(
                '${entry.key} (${(entry.value / distribution.values.fold(0, (a, b) => a + b) * 100).toStringAsFixed(1)}%)',
                provider.getCategoryColor(entry.key),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthProjection(InvestmentProvider provider) {
    final years = [1, 5, 10];
    String selectedYears = '5';
    
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Growth Projection',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: selectedYears,
                  dropdownColor: const Color(0xFF1A1F2E),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  items: const [
                    DropdownMenuItem(
                      value: '1',
                      child: Text('1 Year', style: TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: '5',
                      child: Text('5 Years', style: TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: '10',
                      child: Text('10 Years', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedYears = value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 100000,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final years = ['2026', '2027', '2028', '2029', '2030'];
                        if (value.toInt() >= 0 && value.toInt() < years.length) {
                          return Text(
                            years[value.toInt()],
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '₹${_formatCompactNumber(value)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _getProjectionSpots(provider, int.parse(selectedYears)),
                    isCurved: true,
                    color: const Color(0xFF10B981),
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF10B981).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _getProjectionSpots(InvestmentProvider provider, int years) {
    final currentValue = provider.getTotalCurrentValue(owner: _selectedOwner);
    final spots = <FlSpot>[];
    
    for (int i = 0; i <= years; i++) {
      spots.add(FlSpot(i.toDouble(), currentValue * (1 + (0.12 * i))));
    }
    
    return spots;
  }

  Widget _buildSubcategoryDistribution(InvestmentProvider provider) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🏷️ Fund Distribution by Category',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'See how your investments are spread across different funds',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: provider.getMaxCategoryValue(owner: _selectedOwner) * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final distribution = provider.getCategoryDistribution(
                          owner: _selectedOwner,
                        );
                        final keys = distribution.keys.toList();
                        if (value.toInt() >= 0 && value.toInt() < keys.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              provider.getCategoryIcon(keys[value.toInt()]),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '₹${_formatCompactNumber(value)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                barGroups: _buildBarGroups(provider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(InvestmentProvider provider) {
    final distribution = provider.getCategoryDistribution(owner: _selectedOwner);
    final List<BarChartGroupData> groups = [];
    
    distribution.entries.toList().asMap().forEach((index, entry) {
      groups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: entry.value,
              color: provider.getCategoryColor(entry.key),
              width: 30,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    });
    
    return groups;
  }

  Widget _buildOwnerFundMatrix(InvestmentProvider provider) {
    final hariDistribution = provider.getCategoryDistribution(owner: 'Hari');
    final sangeethaDistribution = provider.getCategoryDistribution(owner: 'Sangeetha');
    final allCategories = {...hariDistribution.keys, ...sangeethaDistribution.keys}.toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '👥 Family Fund Distribution',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Compare Hari's and Sangeetha's investments across each fund",
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 350,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: provider.getMaxCategoryValue() * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < allCategories.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              provider.getCategoryIcon(allCategories[value.toInt()]),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '₹${_formatCompactNumber(value)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                barGroups: List.generate(allCategories.length, (index) {
                  final category = allCategories[index];
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: hariDistribution[category] ?? 0,
                        color: const Color(0xFF5B8CFF),
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: sangeethaDistribution[category] ?? 0,
                        color: const Color(0xFF10B981),
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                    showingTooltipIndicators: [0, 1],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Hari', const Color(0xFF5B8CFF)),
              const SizedBox(width: 16),
              _buildLegendItem('Sangeetha', const Color(0xFF10B981)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshingIndicator() {
    return Positioned(
      top: 100,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFF5B8CFF),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Refreshing...',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  List<Investment> _getFilteredInvestments() {
    return _provider.investments.where((inv) {
      if (_selectedOwner != 'all' && inv.owner != _selectedOwner) return false;
      
      if (_searchQuery.isNotEmpty) {
        return inv.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            inv.comments.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (inv.subCategory?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                false);
      }

      if (_selectedCategory != 'all' && inv.categoryId.toString() != _selectedCategory){
        return false;
      }
      
      if (_selectedDateRange != 'all') {
        final date = DateTime.parse(inv.date);
        final now = DateTime.now();
        
        switch (_selectedDateRange) {
          case 'this-month':
            if (date.month != now.month || date.year != now.year) return false;
            break;
          case 'last-3-months':
            if (date.isBefore(now.subtract(const Duration(days: 90)))) return false;
            break;
          case 'last-6-months':
            if (date.isBefore(now.subtract(const Duration(days: 180)))) return false;
            break;
          case 'this-year':
            if (date.year != now.year) return false;
            break;
        }
      }
      
      return true;
    }).toList();
  }

  String _formatNumber(double number) {
    if (number >= 10000000) {
      return '${(number / 10000000).toStringAsFixed(2)}Cr';
    } else if (number >= 100000) {
      return '${(number / 100000).toStringAsFixed(2)}L';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toStringAsFixed(0);
  }

  String _formatCompactNumber(double number) {
    if (number >= 10000000) {
      return '${(number / 10000000).toStringAsFixed(1)}Cr';
    } else if (number >= 100000) {
      return '${(number / 100000).toStringAsFixed(1)}L';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toStringAsFixed(0);
  }

  void _showAddInvestmentModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddInvestmentModal(
        categories: _provider.categories,
        goals: _provider.financialGoals,
        onSave: (investment) async {

          try {

            await _provider.addInvestment(investment);

            if (mounted) {
              Navigator.pop(context);

              _showSnackBar(
                "Investment saved successfully",
                isSuccess: true,
              );
            }

          } catch (e) {

            _showSnackBar(
              "Error saving investment",
              isSuccess: false,
            );

          }

        },
      ),
    );
  }

  void _showEditInvestmentModal(Investment investment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddInvestmentModal(
        investment: investment,
        categories: _provider.categories,
        goals: _provider.financialGoals,
        onSave: (updated) async {
          await _provider.updateInvestment(updated);
          if (mounted) {
            Navigator.pop(context);
            _showSnackBar('Investment updated successfully', isSuccess: true);
          }
        },
      ),
    );
  }

  void _showRedemptionModal(Investment investment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RedemptionModal(
        investment: investment,
        onRedeem: (amount, notes) async {
          await _provider.redeemInvestment(investment.id, amount, notes);
          if (mounted) {
            Navigator.pop(context);
            _showSnackBar(
              '₹${_formatNumber(amount)} redeemed successfully',
              isSuccess: true,
            );
          }
        },
      ),
    );
  }

  void _showInvestmentDetails(Investment investment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InvestmentDetailModal(
        investment: investment,
        onRedeem: () => _showRedemptionModal(investment),
        onEdit: () => _showEditInvestmentModal(investment),
        onDelete: () => _showDeleteConfirmation(investment),
      ),
    );
  }

  void _showDayDetails(DateTime date, double amount) {
    final dayInvestments = _provider.investments.where((inv) {
      final invDate = DateTime.parse(inv.date);
      return invDate.year == date.year &&
          invDate.month == date.month &&
          invDate.day == date.day;
    }).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          DateFormat('dd MMM yyyy').format(date),
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dayInvestments.isEmpty) ...[
                const Text(
                  'No investments on this day',
                  style: TextStyle(color: Colors.white70),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B8CFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Invested:',
                        style: TextStyle(color: Colors.white),
                      ),
                      Text(
                        '₹${_formatNumber(amount)}',
                        style: const TextStyle(
                          color: Color(0xFF5B8CFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...dayInvestments.map((inv) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _provider.getCategoryColor(inv.category),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                inv.category,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (inv.subCategory != null)
                                Text(
                                  inv.subCategory!,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${_formatNumber(inv.amount)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: inv.owner == 'Hari'
                                    ? const Color(0xFF5B8CFF).withOpacity(0.2)
                                    : const Color(0xFF10B981).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                inv.owner,
                                style: TextStyle(
                                  color: inv.owner == 'Hari'
                                      ? const Color(0xFF5B8CFF)
                                      : const Color(0xFF10B981),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Investment investment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Investment',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete this investment of ₹${_formatNumber(investment.amount)}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _provider.deleteInvestment(investment.id);
              if (mounted) {
                Navigator.pop(context);
                _showSnackBar('Investment deleted successfully', isSuccess: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBulkDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Selected',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedInvestmentIds.length} investments?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              for (final id in _selectedInvestmentIds) {
                await _provider.deleteInvestment(id);
              }
              if (mounted) {
                setState(() => _selectedInvestmentIds.clear());
                Navigator.pop(context);
                _showSnackBar('Investments deleted successfully', isSuccess: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  final deadlineController = TextEditingController();
  void _showAddGoalModal() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1F2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Create Financial Goal",
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Goal Name",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Target Amount",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: deadlineController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Deadline (YYYY-MM-DD)",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),

            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text;
                final target = double.tryParse(targetController.text) ?? 0;

                if (name.isEmpty || target <= 0) return;

                await _provider.addGoal(
                  FinancialGoal(
                    id: '',
                    name: name,
                    targetAmount: target,
                    currentAmount: 0,
                    color: "#5B8CFF",
                    icon: "🎯",
                    deadline: deadlineController.text.isEmpty
                        ? null
                        : DateTime.parse(deadlineController.text),
                  ),
                );

                if (mounted) {
                  Navigator.pop(context);
                  _showSnackBar("Goal created successfully");
                }
              },
              child: const Text("Create"),
            )
          ],
        );
      },
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F2E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download, color: Colors.white70),
              title: const Text(
                'Export Portfolio',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _exportPortfolio();
              },
            ),
            ListTile(
              leading: const Icon(Icons.category, color: Colors.white70),
              title: const Text(
                'Manage Categories',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showManageCategoriesModal();
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics, color: Colors.white70),
              title: const Text(
                'View Report',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _tabController.animateTo(2);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showManageCategoriesModal() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1F2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Manage Categories",
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "New Category",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;

                  _provider.addCategory(
                      Category(
                        id: DateTime.now().millisecondsSinceEpoch,
                        name: name,
                        icon: "💰",
                        color: "#5B8CFF",
                      )
                  );

                  Navigator.pop(context);
                  _showSnackBar("Category added");
                },
                child: const Text("Add Category"),
              )
            ],
          ),
        );
      },
    );
  }

  void _exportPortfolio() {
    // Implementation for exporting portfolio data
    _showSnackBar('Export started', isSuccess: true);
  }

  void _showSnackBar(String message, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}