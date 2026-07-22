import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import 'chat_message.dart';
import 'chat_repository.dart';

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
  String? _typingId; // id ข้อความพี่เงินที่กำลัง "พิมพ์ทีละตัว" (typewriter)

  static const _suggestions = [
    'เดือนนี้ใช้เงินยังไงบ้าง?',
    'อยากเริ่มลงทุน ควรเริ่มยังไง?',
    'จะออมเงินให้ถึงเป้าต้องทำไง?',
  ];

  CoachMood get _mood => _listening
      ? CoachMood.listening
      : (_sending || _attaching ? CoachMood.thinking : CoachMood.idle);

  @override
  void initState() {
    super.initState();
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

  Future<void> _send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _sending) return;
    if (_listening) await _stopListening();
    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(id: 'local', role: 'user', content: msg, createdAt: DateTime.now()));
      _sending = true;
    });
    _scrollToBottom();
    try {
      final reply = await ref.read(chatRepoProvider).send(msg);
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
          content: 'ขอโทษนะ ตอนนี้พี่เงินตอบไม่ได้ ลองใหม่อีกครั้ง 🙏 (เช็คว่า backend รันอยู่)',
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
        maxWidth: 1600, // ย่อรูปให้เบา OCR เร็วขึ้น + ไม่เกิน body limit
      );
      if (file == null) return;
      setState(() => _attaching = true);
      final bytes = await file.readAsBytes();
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final text = await ref.read(chatRepoProvider).ocrImage(dataUrl);
      if (!mounted) return;
      setState(() {
        _attaching = false;
        if (text.trim().isNotEmpty) {
          _controller.text = 'จากรูปที่ส่งมา:\n$text\n\nช่วยวิเคราะห์/แนะนำหน่อย';
        }
      });
      if (text.trim().isEmpty) _snack('อ่านรูปไม่ได้ ลองพิมพ์ข้อมูลจากรูปแทนนะ');
    } catch (e) {
      if (mounted) setState(() => _attaching = false);
      _snack('แนบรูปไม่สำเร็จ: $e');
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('พี่เงิน · ที่ปรึกษาการเงิน AI',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _AvatarHeader(mood: _mood),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      children: [
                        if (_messages.isEmpty) const _Welcome(),
                        ..._messages.map((m) => _Bubble(
                              key: ValueKey(m.id),
                              message: m,
                              animate: !m.isUser && m.id == _typingId,
                              onGrow: _scrollToBottom,
                            )),
                        if (_sending) const _TypingBubble(),
                      ],
                    ),
            ),
            if (_messages.isEmpty && !_loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestions
                      .map((s) => ActionChip(label: Text(s), onPressed: () => _send(s)))
                      .toList(),
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

/// Avatar อนิเมชันของพี่เงิน — หายใจ/เรืองแสง + เปลี่ยนสีหน้า/สถานะตามอารมณ์
class _AvatarHeader extends StatefulWidget {
  const _AvatarHeader({required this.mood});
  final CoachMood mood;
  @override
  State<_AvatarHeader> createState() => _AvatarHeaderState();
}

class _AvatarHeaderState extends State<_AvatarHeader> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

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
    final face = mood == CoachMood.listening
        ? '👂'
        : mood == CoachMood.thinking
            ? '💭'
            : '🤖';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
                child: Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [BoxShadow(color: color.withOpacity(0.45), blurRadius: glow, spreadRadius: 1)],
                  ),
                  child: Text(face, style: const TextStyle(fontSize: 38)),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(label,
                key: ValueKey(label),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
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
              style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 6),
          Text(
            'ถามเรื่องออม ลงทุน ปลดหนี้ หรือวางแผนการเงินได้เลย — ผมเห็นรายรับรายจ่ายของคุณ เลยแนะนำได้ตรงจุด\nพิมพ์ พูด (กดไมค์) หรือส่งรูปสลิป (กดรูป) ก็ได้นะ 💬🎤🖼️',
            style: TextStyle(color: AppColors.textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

/// สไตล์ markdown ของบับเบิลพี่เงิน (ใช้ทั้งแบบนิ่งและแบบพิมพ์ทีละตัว)
MarkdownStyleSheet _coachMdStyle() => MarkdownStyleSheet(
      p: const TextStyle(color: AppColors.textDark, height: 1.45, fontSize: 14),
      strong: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
      listBullet: const TextStyle(color: AppColors.textDark, height: 1.45, fontSize: 14),
      h3: const TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold),
      blockquote: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      blockSpacing: 8,
    );

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.message, this.animate = false, this.onGrow});
  final ChatMessage message;
  final bool animate; // true = ค่อย ๆ พิมพ์ออกมา (เฉพาะข้อความพี่เงินที่เพิ่งตอบ)
  final VoidCallback? onGrow;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: isUser ? null : Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            isUser
                ? Text(message.content, style: const TextStyle(color: Colors.white, height: 1.4))
                : animate
                    ? _TypewriterMarkdown(text: message.content, onGrow: onGrow)
                    : MarkdownBody(data: message.content, selectable: true, styleSheet: _coachMdStyle()),
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
    final isExcel = att.format == 'xlsx';
    return OutlinedButton.icon(
      onPressed: () {
        final url = '$kApiBaseUrl/api/v1/export/${att.kind}?format=${att.format}&dt=${att.token}';
        launchUrl(Uri.parse(url), webOnlyWindowName: '_blank', mode: LaunchMode.externalApplication);
      },
      icon: Icon(isExcel ? Icons.table_chart_outlined : Icons.code, size: 18, color: AppColors.primary),
      label: Text('ดาวน์โหลด ${att.filename}',
          style: const TextStyle(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w600)),
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
  const _TypewriterMarkdown({required this.text, this.onGrow});
  final String text;
  final VoidCallback? onGrow;

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
      // เลื่อนจอตามข้อความที่ยาวขึ้น (throttle ทุก ~6 tick)
      if (widget.onGrow != null && (_done || _shown % (step * 6) < step)) widget.onGrow!();
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
    return MarkdownBody(data: data, selectable: _done, styleSheet: _coachMdStyle());
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: const Text('พี่เงินกำลังคิด... 💭', style: TextStyle(color: AppColors.textMuted)),
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
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'แนบรูป/สลิป',
                onPressed: attaching ? null : onImage,
                icon: attaching
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.image_outlined, color: AppColors.primary),
              ),
              IconButton(
                tooltip: 'พูด',
                onPressed: onMic,
                icon: Icon(listening ? Icons.mic : Icons.mic_none,
                    color: listening ? AppColors.expense : AppColors.primary),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: listening ? 'กำลังฟัง... พูดได้เลย' : 'พิมพ์ หรือกดไมค์ 🎤 / รูป 🖼️',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: busy ? null : onSend,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'พี่เงินเป็น AI • ข้อมูลทั่วไปเพื่อการศึกษา ไม่ใช่คำแนะนำการลงทุนเฉพาะบุคคล',
            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
