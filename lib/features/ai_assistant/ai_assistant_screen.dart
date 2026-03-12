// Replace your existing AiAssistantScreen with this updated version
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'ai_assistant_service.dart';
import 'package:hflow/core/widgets/ai_data_display.dart';

class AiAssistantScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const AiAssistantScreen({super.key, this.onBack});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  static const double _headerHeight = 56;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final AIAssistantService _aiService = AIAssistantService();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Add welcome message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: "Hello! I'm your AI financial assistant. I can help you with:\n\n"
                "📊 Invoices - Check status, totals, or create new ones\n"
                "💰 Expenses - Track spending, analyze categories\n"
                "📈 Investments - Monitor SIPs and investment portfolio\n"
                "📋 Clients - View client information and history\n"
                "🧾 Tax - Get tax estimates and deduction insights\n"
                "🎯 Goals - Track progress on financial goals\n\n"
                "What would you like to know about your finances today?",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final query = _controller.text;
    _controller.clear();

    setState(() {
      _isTyping = true;
    });

    // Process query
    final response = await _aiService.processQuery(query);

    setState(() {
      _messages.addAll(_aiService.messageHistory.skip(_messages.length));
      _isTyping = false;
    });

    _scrollToBottom();
  }

  void _handleQuickPrompt(String prompt) {
    _controller.text = prompt;
    _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B0F1A), Color(0xFF05060A)],
            ),
          ),
        ),

        // Blurred blobs for visual interest
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

        // Main content
        SafeArea(
          child: Column(
            children: [
              _glassHeader(),
              const SizedBox(height: 12),

              // Messages list
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return Column(
                      children: [
                        _MessageBubble(message: message),
                        if (message.data != null && !message.isUser)
                          AIDataDisplay(
                            data: message.data,
                            dataType: message.dataType,
                          ),
                      ],
                    );
                  },
                ),
              ),

              // Typing indicator
              if (_isTyping)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Color(0xFF5B8CFF),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        "AI is thinking...",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),

              // Quick prompts
              if (_messages.length <= 2)
                _QuickPrompts(onPromptSelected: _handleQuickPrompt),

              // Input bar
              _InputBar(
                controller: _controller,
                focusNode: _focusNode,
                onSend: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _glassHeader() {
    return Container(
      height: _headerHeight,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SafeArea(
        bottom: false,
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
                }
              },
            ),
            const Expanded(
              child: Text(
                "AI Financial Assistant",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.refresh,
                size: 18,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _messages.clear();
                  _messages.add(
                    ChatMessage(
                      text: "Hello! I'm your AI financial assistant. How can I help you today?",
                      isUser: false,
                      timestamp: DateTime.now(),
                    ),
                  );
                });
                _aiService.clearHistory();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _liquidBlob({
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

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.all(14),
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                color: message.isUser
                    ? const Color(0xFF5B8CFF)
                    : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 16),
                ),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('hh:mm a').format(message.timestamp),
                    style: TextStyle(
                      color: message.isUser
                          ? Colors.white.withOpacity(0.7)
                          : Colors.white.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickPrompts extends StatelessWidget {
  final Function(String) onPromptSelected;

  const _QuickPrompts({required this.onPromptSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        scrollDirection: Axis.horizontal,
        children: [
          _PromptCard(
            icon: Icons.receipt_long,
            text: "Show my recent invoices",
            colors: const [Color(0xFF4F46E5), Color(0xFF6366F1)],
            onTap: () => onPromptSelected("Show my recent invoices"),
          ),
          _PromptCard(
            icon: Icons.trending_up,
            text: "Monthly expenses",
            colors: const [Color(0xFF06B6D4), Color(0xFF3B82F6)],
            onTap: () => onPromptSelected("What are my monthly expenses?"),
          ),
          _PromptCard(
            icon: Icons.account_balance,
            text: "Investment summary",
            colors: const [Color(0xFF8B5CF6), Color(0xFFEC4899)],
            onTap: () => onPromptSelected("Show my investment summary"),
          ),
          _PromptCard(
            icon: Icons.people,
            text: "Top clients",
            colors: const [Color(0xFF10B981), Color(0xFF22C55E)],
            onTap: () => onPromptSelected("Who are my top clients?"),
          ),
          _PromptCard(
            icon: Icons.calculate,
            text: "Tax estimate",
            colors: const [Color(0xFFF59E0B), Color(0xFFF97316)],
            onTap: () => onPromptSelected("What's my tax estimate?"),
          ),
          _PromptCard(
            icon: Icons.emoji_events,
            text: "Financial goals",
            colors: const [Color(0xFFEF4444), Color(0xFFF43F5E)],
            onTap: () => onPromptSelected("Show my financial goals"),
          ),
        ],
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final List<Color> colors;
  final VoidCallback onTap;

  const _PromptCard({
    required this.icon,
    required this.text,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: colors),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Ask about invoices, expenses, investments...",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF5B8CFF),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B8CFF).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}