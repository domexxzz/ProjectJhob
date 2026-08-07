import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kTourHomeDone = 'tour_home_done';

/// จำว่าผู้ใช้ดูทัวร์แนะนำหน้าหลักไปแล้วหรือยัง
/// - null  = ยังอ่านค่าไม่เสร็จ (อย่าเพิ่งเปิดทัวร์)
/// - false = ยังไม่เคยดู → เปิดทัวร์ให้อัตโนมัติ
/// - true  = ดูแล้ว/กดข้าม → ไม่ต้องเปิดอีก (ดูซ้ำได้จากเมนู)
class TourDoneNotifier extends StateNotifier<bool?> {
  TourDoneNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kTourHomeDone) ?? false;
  }

  Future<void> markDone() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTourHomeDone, true);
  }

  /// ให้ผู้ใช้กด "ดูวิธีใช้อีกครั้ง" จากเมนูได้
  Future<void> reset() async {
    state = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTourHomeDone, false);
  }
}

final tourDoneProvider =
    StateNotifierProvider<TourDoneNotifier, bool?>((ref) => TourDoneNotifier());
