import 'package:flutter/material.dart';
import '../services/calz_ai_coach_service.dart';
import 'calz_mascot_widget.dart';

class CalzAICoachSheet extends StatefulWidget {
  const CalzAICoachSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CalzAICoachSheet(),
    );
  }

  @override
  State<CalzAICoachSheet> createState() => _CalzAICoachSheetState();
}

class _CalzAICoachSheetState extends State<CalzAICoachSheet> {
  final List<CalzChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialSummary();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialSummary() async {
    setState(() => _isLoading = true);
    final summary = await CalzAICoachService.instance.generateDailyHealthSummary();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _messages.add(
        CalzChatMessage(
          text: summary,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  Future<void> _handleSendMessage([String? predefinedText]) async {
    final text = predefinedText ?? _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (predefinedText == null) {
      _textController.clear();
    }

    setState(() {
      _messages.add(CalzChatMessage(text: text, isUser: true, timestamp: DateTime.now()));
      _isLoading = true;
    });

    _scrollToBottom();

    final response = await CalzAICoachService.instance.answerUserQuestion(text);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _messages.add(CalzChatMessage(text: response, isUser: false, timestamp: DateTime.now()));
    });

    _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFFF9F7F4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD6D0C7),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),

          // Header with Mascot
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                const SizedBox(
                  width: 54,
                  height: 54,
                  child: CalzMascotWidget(size: 54),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Calz AI Health Coach',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111111),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Personalized insights & daily advice',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6F6A64)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF111111)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE6E0D7), height: 24),

          // Quick Action Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildPromptChip('🍽️ What to eat for dinner?', () => _handleSendMessage('What should I eat for dinner tonight?')),
                const SizedBox(width: 8),
                _buildPromptChip('🏃 Am I on track with steps?', () => _handleSendMessage('Am I on track for my step goal today?')),
                const SizedBox(width: 8),
                _buildPromptChip('💧 Hydration status', () => _handleSendMessage('How is my hydration today?')),
                const SizedBox(width: 8),
                _buildPromptChip('⌚ Check ESP32 Vitals', () => _handleSendMessage('Summarize my ESP32 heart rate and health readings.')),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // Loading indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Row(
                children: const [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF7A59)),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Calz AI is thinking...',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6F6A64), fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          // Input Box
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 10,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Ask Calz AI anything about your health...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9E9991)),
                      filled: true,
                      fillColor: const Color(0xFFF4F1EC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: () => _handleSendMessage(),
                  backgroundColor: const Color(0xFFFF7A59),
                  elevation: 2,
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111111))),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE0D8CE)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: onTap,
    );
  }

  Widget _buildMessageBubble(CalzChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFFFF0E6),
              child: Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFFFF7A59)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFFFF7A59) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isUser ? Colors.white : const Color(0xFF111111),
                  fontWeight: isUser ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF111111),
              child: Icon(Icons.person_rounded, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}
