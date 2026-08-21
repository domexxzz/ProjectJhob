import os
import sys
import time

# ลองนำเข้าไลบรารีของ Gemini หากไม่มีจะทำการติดตั้งให้อัตโนมัติ
try:
    import google.generativeai as genai
except ImportError:
    print("กำลังติดตั้ง google-generativeai ในเครื่องของคุณ...")
    import subprocess
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "google-generativeai"])
        import google.generativeai as genai
        print("ติดตั้ง google-generativeai สำเร็จ!")
    except Exception as e:
        print(f"ไม่สามารถติดตั้งไลบรารีได้อัตโนมัติ: {e}")
        print("กรุณารันคำสั่ง: pip install google-generativeai ก่อนรันสคริปต์นี้")
        sys.exit(1)

def generate_script():
    print("==================================================")
    print("  เครื่องมือวิเคราะห์วิดีโอและสร้างบทสอนใช้งานด้วย Gemini  ")
    print("==================================================")
    
    # 1. ตรวจหาหรือรับค่า API Key
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        api_key = input("กรุณากรอก Gemini API Key ของคุณ (ดูวิธีสมัครได้ที่ aistudio.google.com): ").strip()
        if not api_key:
            print("ข้อผิดพลาด: จำเป็นต้องระบุ API Key เพื่อเรียกใช้ Gemini")
            return
            
    genai.configure(api_key=api_key)
    
    # 2. ตรวจหาไฟล์วิดีโอในเครื่อง
    video_path = os.path.join("wallframe", "animation.mp4")
    if not os.path.exists(video_path):
        video_path = "animation.mp4"
        if not os.path.exists(video_path):
            video_path = input("ไม่พบไฟล์ wallframe/animation.mp4 กรุณากรอกพิกัดไฟล์วิดีโอของคุณ: ").strip()
            if not os.path.exists(video_path):
                print(f"ข้อผิดพลาด: ไม่พบไฟล์วิดีโอที่ {video_path}")
                return

    # 3. อัปโหลดวิดีโอขึ้นระบบ Gemini
    print(f"\n[1/3] กำลังอัปโหลดวิดีโอ {video_path} ไปยัง Google Gemini API...")
    try:
        video_file = genai.upload_file(path=video_path)
    except Exception as e:
        print(f"ข้อผิดพลาดในการอัปโหลด: {e}")
        return

    # 4. รอการประมวลผลไฟล์วิดีโอจากระบบคลาวด์ของ Google
    print("[2/3] กำลังรอให้ Gemini API ประมวลผลวิดีโอ (อาจใช้เวลาประมาณ 1-2 นาที)...")
    while video_file.state.name == "PROCESSING":
        print(".", end="", flush=True)
        time.sleep(10)
        video_file = genai.get_file(video_file.name)
        
    if video_file.state.name == "FAILED":
        print("\nข้อผิดพลาด: การประมวลผลวิดีโอล้มเหลว")
        return

    # 5. สั่งวิเคราะห์และสร้างบทพูด (Voiceover Script)
    print("\n[3/3] ประมวลผลวิดีโอสำเร็จ! กำลังวิเคราะห์และเขียนบทสอนใช้งานภาษาไทย...")
    prompt = """
    วิเคราะห์ขั้นตอนการใช้งานจากวิดีโอสาธิตแอปนี้อย่างละเอียด และเขียนสิ่งต่อไปนี้:
    1. บทพูดผู้บรรยาย (Voiceover Script) ภาษาไทย ที่น่าฟัง กระชับ เข้าใจง่าย และดูพรีเมียม
    2. ลำดับภาพ Storyboard ทีละวินาที ว่าแต่ละวินาทีแสดงอะไรบนหน้าจอและคนพูดควรพูดประโยคอะไร
    3. คำแนะนำเพิ่มเติมสำหรับการตัดต่อวิดีโอและทำคลิปนี้ไปโปรโมตแอป
    กรุณาเขียนผลลัพธ์ทั้งหมดออกมาในรูปแบบ Markdown ที่สวยงามและอ่านง่าย
    """
    
    try:
        model = genai.GenerativeModel(model_name="gemini-1.5-flash")
        response = model.generate_content([video_file, prompt])
        
        output_file = "tutorial_script.md"
        with open(output_file, "w", encoding="utf-8") as f:
            f.write(response.text)
            
        print("\n==================================================")
        print("  สร้างบทสอนใช้งานสำเร็จแล้ว!")
        print("==================================================")
        print(f"บันทึกผลลัพธ์ไว้ที่ไฟล์: {os.path.abspath(output_file)}")
        print("คุณสามารถเปิดไฟล์ดังกล่าวเพื่อนำบทพูดไปใช้ทำคลิปได้ทันทีครับ\n")
        
    except Exception as e:
        print(f"เกิดข้อผิดพลาดในการวิเคราะห์: {e}")
        
    finally:
        # ลบไฟล์ออกจากระบบคลาวด์ของ Gemini เพื่อความปลอดภัยและเป็นส่วนตัว
        try:
            genai.delete_file(video_file.name)
        except:
            pass

if __name__ == "__main__":
    generate_script()
