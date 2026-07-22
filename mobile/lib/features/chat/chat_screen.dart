import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import 'chat_message.dart';
import 'chat_repository.dart';
import '../../widgets/app_bottom_nav_bar.dart';

enum CoachMood { idle, listening, thinking }

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  final SpeechToText _speech = SpeechToText();
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _sending = false;
  bool _listening = false;
  bool _attaching = false;
  bool _sttAvailable = false;
  bool _menuExpanded = false;
  bool _showJumpToLatest = false;
  String? _typingId; // id ข้อความพี่เงินที่กำลัง "พิมพ์ทีละตัว" (typewriter)

  CoachMood get _mood => _listening
      ? CoachMood.listening
      : (_sending || _attaching || _typingId != null
          ? CoachMood.thinking
          : CoachMood.idle);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_handleScroll);
    _init();
  }

  Future<void> _init() async {
    try {
      _sttAvailable = await _speech.initialize();
    } catch (_) {
      _sttAvailable = false;
    }
    await _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final h = await ref.read(chatRepoProvider).history();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(h);
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send(String text, {String? imageBase64}) async {
    final msg = text.trim();
    if (msg.isEmpty || _sending) return;
    if (_listening) await _stopListening();
    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(
        id: 'local',
        role: 'user',
        content: msg,
        createdAt: DateTime.now(),
        hasImage: imageBase64 != null,
      ));
      _sending = true;
      _menuExpanded = false;
    });
    _scrollToBottom();
    try {
      final reply =
          await ref.read(chatRepoProvider).send(msg, imageBase64: imageBase64);
      if (!mounted) return;
      setState(() {
        _messages.add(reply);
        _typingId = reply.id; // ให้ค่อย ๆ พิมพ์ออกมา
        _sending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          id: 'err',
          role: 'assistant',
          content:
              'ขอโทษนะ ตอนนี้พี่เงินตอบไม่ได้ ลองใหม่อีกครั้ง 🙏 (เช็คว่า backend รันอยู่)',
          createdAt: DateTime.now(),
        ));
        _sending = false;
      });
    }
    _scrollToBottom();
  }

  Future<void> _toggleMic() async {
    if (!_sttAvailable) {
      _snack('อุปกรณ์/เบราว์เซอร์นี้ยังไม่รองรับการรับเสียง');
      return;
    }
    if (_listening) {
      await _stopListening();
    } else {
      setState(() => _listening = true);
      await _speech.listen(
        localeId: 'th_TH',
        onResult: (r) => setState(() => _controller.text = r.recognizedWords),
      );
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _attachImage() async {
    if (_attaching) return;
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (file == null) return;
      setState(() => _attaching = true);
      final bytes = await file.readAsBytes();
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      if (!mounted) return;
      setState(() => _attaching = false);

      // ดึงข้อความในช่องพิมพ์มาส่งร่วมด้วย หากไม่มีจะใช้ข้อความเริ่มต้น
      final textToSend = _controller.text.trim().isNotEmpty
          ? _controller.text.trim()
          : 'ช่วยวิเคราะห์รูปภาพนี้ให้หน่อยครับ';

      _controller.clear();
      _send(textToSend, imageBase64: dataUrl);
    } catch (e) {
      if (mounted) setState(() => _attaching = false);
      _snack('แนบรูปไม่สำเร็จ: $e');
    }
  }

  void _snack(String m) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _handleScroll() {
    if (!_scroll.hasClients) return;
    final distanceFromBottom =
        _scroll.position.maxScrollExtent - _scroll.position.pixels;
    final shouldShow = distanceFromBottom > 180;
    if (mounted && shouldShow != _showJumpToLatest) {
      setState(() => _showJumpToLatest = shouldShow);
    }
  }

  void _followLatestMessage() {
    if (!_showJumpToLatest) _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final hasConversation = _messages.isNotEmpty;
    final showFullMenu = !hasConversation || _menuExpanded;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          onPressed: () {
            if (Navigator.of(context).canPop() || context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            children: [
              TextSpan(text: 'พี่', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'เงิน', style: TextStyle(color: Color(0xFF3CAE63))),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _AvatarHeader(mood: _mood),
            _RichMenu(
              busy: _sending,
              expanded: showFullMenu,
              canCollapse: hasConversation,
              onToggle: () => setState(() => _menuExpanded = !_menuExpanded),
              onSelected: (prompt) {
                setState(() => _menuExpanded = false);
                _send(prompt);
              },
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: ListView(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 70),
                            children: [
                              if (_messages.isEmpty) const _Welcome(),
                              ..._messages.map((m) => _Bubble(
                                    key: ValueKey(m.id),
                                    message: m,
                                    animate: !m.isUser && m.id == _typingId,
                                    onGrow: _followLatestMessage,
                                    onTypingComplete: !m.isUser &&
                                            m.id == _typingId
                                        ? () {
                                            if (mounted && _typingId == m.id) {
                                              setState(() => _typingId = null);
                                            }
                                          }
                                        : null,
                                  )),
                              if (_sending) const _TypingBubble(),
                            ],
                          ),
                        ),
                        if (_showJumpToLatest)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 12,
                            child: Center(
                              child: Tooltip(
                                message: 'ไปยังข้อความล่าสุด',
                                child: Material(
                                  color: AppColors.primary,
                                  shape: const CircleBorder(),
                                  elevation: 6,
                                  shadowColor: Colors.black54,
                                  child: InkWell(
                                    onTap: _scrollToBottom,
                                    customBorder: const CircleBorder(),
                                    child: const SizedBox(
                                      width: 46,
                                      height: 46,
                                      child: Icon(
                                        Icons
                                            .keyboard_double_arrow_down_rounded,
                                        color: Colors.white,
                                        size: 25,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            _InputBar(
              controller: _controller,
              listening: _listening,
              attaching: _attaching,
              busy: _sending,
              onMic: _toggleMic,
              onImage: _attachImage,
              onSend: () => _send(_controller.text),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rich Menu ลัดไปยังงานการเงินที่ใช้บ่อย โดยคงพื้นที่แชทไว้เป็นสัดส่วนหลัก
class _RichMenuItem {
  const _RichMenuItem({
    required this.emoji,
    required this.label,
    required this.description,
    required this.prompt,
    required this.accent,
  });

  final String emoji;
  final String label;
  final String description;
  final String prompt;
  final Color accent;
}

class _RichMenu extends StatelessWidget {
  const _RichMenu({
    required this.busy,
    required this.expanded,
    required this.canCollapse,
    required this.onToggle,
    required this.onSelected,
  });

  final bool busy;
  final bool expanded;
  final bool canCollapse;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelected;

  static const _items = [
    _RichMenuItem(
      emoji: '💰',
      label: 'วิเคราะห์การเงิน',
      description: 'เช็กพฤติกรรมการใช้เงิน และค้นหาโอกาสปรับแผน',
      prompt: 'ช่วยวิเคราะห์ภาพรวมการเงินของฉันให้หน่อย',
      accent: Color(0xFF70D94B),
    ),
    _RichMenuItem(
      emoji: '🎯',
      label: 'ตั้งเป้าหมาย',
      description: 'ตั้งเป้าหมายการออม ให้สำเร็จตามแผน',
      prompt: 'ช่วยฉันตั้งเป้าหมายการเงินที่ทำได้จริง',
      accent: Color(0xFF9B72E8),
    ),
    _RichMenuItem(
      emoji: '📊',
      label: 'ปรึกษาการลงทุน',
      description: 'วิเคราะห์พอร์ตและรับคำแนะนำจาก AI',
      prompt: 'ฉันอยากปรึกษาเรื่องการลงทุน ควรเริ่มอย่างไรดี',
      accent: Color(0xFF4A9EEA),
    ),
    _RichMenuItem(
      emoji: '💸',
      label: 'บันทึกรายจ่าย',
      description: 'บันทึกง่าย รวดเร็ว ด้วย AI ช่วยจำแนก',
      prompt: 'ช่วยฉันบันทึกรายจ่ายรายการใหม่',
      accent: Color(0xFFE9952D),
    ),
    _RichMenuItem(
      emoji: '📈',
      label: 'สรุปรายเดือน',
      description: 'ดูภาพรวมรายรับ รายจ่าย และเงินคงเหลือ',
      prompt: 'ช่วยสรุปรายรับรายจ่ายของฉันในเดือนนี้',
      accent: Color(0xFF2FC9B4),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: OutlinedButton.icon(
            onPressed: busy ? null : onToggle,
            icon: const Icon(Icons.auto_awesome_rounded, size: 17),
            label: const Text('เมนูแนะนำ'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: Color(0xFF27543A)),
              backgroundColor: const Color(0xFF102219),
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 8),
                child: Row(
                  children: [
                    const Text(
                      'เมนูแนะนำ',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (canCollapse)
                      InkWell(
                        onTap: onToggle,
                        borderRadius: BorderRadius.circular(16),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.keyboard_arrow_up_rounded,
                              color: AppColors.textMuted, size: 20),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 154,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 9.0;
                    final showAll = constraints.maxWidth >= 780;
                    final cardWidth = showAll
                        ? (constraints.maxWidth - (gap * 4)) / 5
                        : (constraints.maxWidth * 0.43).clamp(148.0, 174.0);

                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: showAll
                          ? const NeverScrollableScrollPhysics()
                          : const BouncingScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: gap),
                      itemBuilder: (context, index) => SizedBox(
                        width: cardWidth,
                        child: _RichMenuCard(
                          item: _items[index],
                          busy: busy,
                          onTap: () => onSelected(_items[index].prompt),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RichMenuCard extends StatelessWidget {
  const _RichMenuCard({
    required this.item,
    required this.busy,
    required this.onTap,
  });

  final _RichMenuItem item;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: busy ? 0.55 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: item.accent.withValues(alpha: 0.55)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  item.accent.withValues(alpha: 0.28),
                  const Color(0xFF101923),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: item.accent.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 14,
                  top: 13,
                  child: Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: item.accent.withValues(alpha: 0.38),
                  ),
                ),
                Positioned(
                  right: 42,
                  top: 43,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: item.accent.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.emoji, style: const TextStyle(fontSize: 32)),
                      const Spacer(),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(right: 22),
                        child: Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: item.accent.withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar อนิเมชันของพี่เงิน — หายใจ/เรืองแสง + เปลี่ยนสีหน้า/สถานะตามอารมณ์
class _AvatarHeader extends StatefulWidget {
  const _AvatarHeader({required this.mood});
  final CoachMood mood;
  @override
  State<_AvatarHeader> createState() => _AvatarHeaderState();
}

class _AvatarHeaderState extends State<_AvatarHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mood = widget.mood;
    final color = mood == CoachMood.listening
        ? AppColors.accent
        : mood == CoachMood.thinking
            ? const Color(0xFFFFA94D)
            : AppColors.primary;
    final label = mood == CoachMood.listening
        ? 'กำลังฟัง... พูดได้เลย'
        : mood == CoachMood.thinking
            ? 'กำลังคิด...'
            : 'พร้อมให้คำปรึกษา';
    final statusIcon = mood == CoachMood.listening
        ? Icons.mic_rounded
        : mood == CoachMood.thinking
            ? Icons.more_horiz_rounded
            : Icons.check_rounded;
    final avatarAsset = mood == CoachMood.thinking
        ? 'assets/images/chat_typing_v2.png'
        : 'assets/images/chat_avatar_v2.png';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final t = _c.value;
              final pulse = mood == CoachMood.idle ? 0.04 : 0.10;
              final scale = 1.0 + pulse * t;
              final glow = (mood == CoachMood.idle ? 8.0 : 16.0) + 10 * t;
              return Transform.scale(
                scale: scale,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.45),
                            blurRadius: glow,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: ClipOval(
                        child: SizedBox.expand(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            layoutBuilder: (currentChild, previousChildren) {
                              return Stack(
                                fit: StackFit.expand,
                                alignment: Alignment.center,
                                children: [
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              );
                            },
                            child: Image.asset(
                              avatarAsset,
                              key: ValueKey(avatarAsset),
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF0D1117), width: 2),
                        ),
                        child: Icon(statusIcon, color: Colors.white, size: 12),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(label,
                key: ValueKey(label),
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('สวัสดีครับ ผมพี่เงิน ที่ปรึกษาการเงินของคุณ 🤝',
              style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          SizedBox(height: 6),
          Text(
            'ถามเรื่องรายรับ–รายจ่าย การออม หนี้ ภาษี ประกัน ลงทุน หรือเกษียณได้เลย — ผมเห็นข้อมูลการเงินของคุณ จึงช่วยวางแผนได้ตรงจุด\nพิมพ์ พูด (กดไมค์) หรือส่งรูปสลิป (กดรูป) ก็ได้นะ 💬🎤🖼️',
            style: TextStyle(color: AppColors.textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

// ใช้สีเฉพาะหน้าแชทเพื่อให้ข้อความอ่านง่ายและไม่เปลี่ยนตามสี primary ของแอป
const _userBubbleColor = Color(0xFF075985);
const _coachBubbleColor = Color(0xFF1E293B);
const _chatTextColor = Color(0xFFF8FAFC);
const _chatMutedTextColor = Color(0xFFCBD5E1);

/// สไตล์ markdown ของบับเบิลพี่เงิน (ใช้ทั้งแบบนิ่งและแบบพิมพ์ทีละตัว)
MarkdownStyleSheet _coachMdStyle() => MarkdownStyleSheet(
      p: const TextStyle(color: _chatTextColor, height: 1.45, fontSize: 14),
      strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      listBullet:
          const TextStyle(color: _chatTextColor, height: 1.45, fontSize: 14),
      h3: const TextStyle(
          color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
      blockquote: const TextStyle(
        color: _chatTextColor,
        fontSize: 13,
        height: 1.5,
        fontWeight: FontWeight.w500,
      ),
      blockquotePadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      blockquoteDecoration: BoxDecoration(
        color: const Color(0xFF0F3B5A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF38BDF8), width: 1.2),
      ),
      tableHead: const TextStyle(
          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
      tableBody: const TextStyle(color: _chatTextColor, fontSize: 13),
      tableBorder: TableBorder.all(color: const Color(0xFF475569), width: 0.8),
      tableCellsPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      tableHeadCellsDecoration: const BoxDecoration(color: Color(0xFF243244)),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF334155), width: 1)),
      ),
      blockSpacing: 8,
    );

class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.message,
    this.animate = false,
    this.onGrow,
    this.onTypingComplete,
  });
  final ChatMessage message;
  final bool
      animate; // true = ค่อย ๆ พิมพ์ออกมา (เฉพาะข้อความพี่เงินที่เพิ่งตอบ)
  final VoidCallback? onGrow;
  final VoidCallback? onTypingComplete;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * (isUser ? 0.8 : 0.9)),
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.symmetric(
            horizontal: isUser ? 14 : 0, vertical: isUser ? 10 : 4),
        decoration: BoxDecoration(
          color: isUser ? _userBubbleColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isUser
              ? Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.55))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isUser) ...[
              const Text(
                'พี่เงิน',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
            ],
            if (isUser && message.hasImage) ...[
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_outlined, color: Colors.white70, size: 16),
                  SizedBox(width: 6),
                  Text('ส่งรูปภาพแล้ว',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 6),
            ],
            isUser
                ? Text(message.content,
                    style: const TextStyle(
                      color: _chatTextColor,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ))
                : animate
                    ? _TypewriterMarkdown(
                        text: message.content,
                        onGrow: onGrow,
                        onComplete: onTypingComplete,
                      )
                    : MarkdownBody(
                        data: message.content,
                        selectable: true,
                        styleSheet: _coachMdStyle()),
            // ปุ่มดาวน์โหลดไฟล์ที่พี่เงินสร้างให้ (Excel/XML)
            if (!isUser && message.attachment != null) ...[
              const SizedBox(height: 10),
              _DownloadButton(att: message.attachment!),
            ],
          ],
        ),
      ),
    );
  }
}

/// ปุ่มดาวน์โหลดไฟล์การเงินจากพี่เงิน — เปิด URL export (auth ด้วย download token)
class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.att});
  final ChatAttachment att;

  @override
  Widget build(BuildContext context) {
    final icon = switch (att.format) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'xlsx' || 'csv' => Icons.table_chart_outlined,
      'docx' || 'txt' || 'html' => Icons.description_outlined,
      _ => Icons.code,
    };
    return OutlinedButton.icon(
      onPressed: () {
        final url =
            '$kApiBaseUrl/api/v1/export/${att.kind}?format=${att.format}&dt=${att.token}';
        launchUrl(Uri.parse(url),
            webOnlyWindowName: '_blank', mode: LaunchMode.externalApplication);
      },
      icon: Icon(icon, size: 18, color: AppColors.primary),
      label: Text('ดาวน์โหลด ${att.filename}',
          style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.primary.withOpacity(0.08),
      ),
    );
  }
}

/// ค่อย ๆ เผยข้อความทีละไม่กี่ตัวอักษร + เคอร์เซอร์กะพริบ จนครบแล้วโชว์ markdown เต็ม
class _TypewriterMarkdown extends StatefulWidget {
  const _TypewriterMarkdown({
    required this.text,
    this.onGrow,
    this.onComplete,
  });
  final String text;
  final VoidCallback? onGrow;
  final VoidCallback? onComplete;

  @override
  State<_TypewriterMarkdown> createState() => _TypewriterMarkdownState();
}

class _TypewriterMarkdownState extends State<_TypewriterMarkdown> {
  Timer? _timer;
  int _shown = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // เร็วขึ้นตามความยาว: ข้อความยาวเผยทีละหลายตัว จะได้ไม่ช้าเกินไป
    final step = (widget.text.length / 150).ceil().clamp(1, 8);
    _timer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (!mounted) return;
      setState(() {
        _shown = (_shown + step).clamp(0, widget.text.length);
        if (_shown >= widget.text.length) {
          _done = true;
          t.cancel();
        }
      });
      if (_done) widget.onComplete?.call();
      // เลื่อนจอตามข้อความที่ยาวขึ้น (throttle ทุก ~6 tick)
      if (widget.onGrow != null && (_done || _shown % (step * 6) < step))
        widget.onGrow!();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ระหว่างพิมพ์ต่อท้ายด้วยเคอร์เซอร์ "▍"; ครบแล้วเอาออก + selectable
    final data = _done ? widget.text : '${widget.text.substring(0, _shown)}▍';
    return MarkdownBody(
        data: data, selectable: _done, styleSheet: _coachMdStyle());
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _coachBubbleColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFF64748B).withValues(alpha: 0.55)),
        ),
        child: const Text('พี่เงินกำลังคิด... 💭',
            style: TextStyle(color: _chatMutedTextColor)),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.listening,
    required this.attaching,
    required this.busy,
    required this.onMic,
    required this.onImage,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool listening;
  final bool attaching;
  final bool busy;
  final VoidCallback onMic;
  final VoidCallback onImage;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF16202E),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'แนบรูปหรือสลิป',
                  onPressed: attaching ? null : onImage,
                  icon: attaching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.image_outlined,
                          color: AppColors.primary),
                ),
                IconButton(
                  tooltip: 'พูด',
                  onPressed: onMic,
                  icon: Icon(listening ? Icons.mic : Icons.mic_none,
                      color: listening ? AppColors.expense : AppColors.primary),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, height: 1.35),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: InputDecoration.collapsed(
                        hintText: listening
                            ? 'กำลังฟัง... พูดได้เลย'
                            : 'ถามเรื่องการเงิน...',
                        hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 14),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    tooltip: 'ส่งข้อความ',
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                    onPressed: busy ? null : onSend,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'พี่เงินเป็น AI • ข้อมูลทั่วไปเพื่อการศึกษา ไม่ใช่คำแนะนำการลงทุนเฉพาะบุคคล',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
