# XML Templates — ไฟล์การเงิน

ทุกไฟล์ขึ้นต้นด้วย `<?xml version="1.0" encoding="UTF-8"?>` · เงินหน่วย "บาท" ทศนิยม 2 ตำแหน่ง · escape `&amp; &lt; &gt;` · วันที่แบบ `YYYY-MM-DD`

> หมายเหตุ: ข้อมูลในแอปพี่เงินเก็บเป็น "สตางค์" (int) — เวลา export เป็น XML ให้หาร 100 เป็นบาทก่อน

---

## budget.xml — งบประมาณรายหมวด

```xml
<?xml version="1.0" encoding="UTF-8"?>
<budget currency="THB" period="monthly" month="2026-07">
  <owner>สมชาย</owner>
  <categories>
    <category name="อาหาร" limit="8000.00" spent="6500.00" remaining="1500.00"/>
    <category name="เดินทาง" limit="3000.00" spent="3500.00" remaining="-500.00" status="over"/>
    <category name="ช้อปปิ้ง" limit="2000.00" spent="900.00" remaining="1100.00"/>
  </categories>
  <total limit="13000.00" spent="10900.00" remaining="2100.00"/>
</budget>
```

## transactions.xml — รายการเดินบัญชี (export)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<transactions currency="THB" from="2026-07-01" to="2026-07-31">
  <transaction id="txn_001" date="2026-07-03" type="expense" amount="120.00" category="อาหาร" source="ocr">
    <note>ข้าวกะเพรา ร้านอาหารตามสั่ง</note>
  </transaction>
  <transaction id="txn_002" date="2026-07-05" type="expense" amount="250.00" category="ช้อปปิ้ง" source="manual">
    <note>Shopee</note>
  </transaction>
  <transaction id="txn_003" date="2026-07-25" type="income" amount="25000.00" category="เงินเดือน" source="manual">
    <note>เงินเดือน ก.ค.</note>
  </transaction>
  <summary income="25000.00" expense="370.00" balance="24630.00"/>
</transactions>
```

## financial-summary.xml — สรุปการเงิน

```xml
<?xml version="1.0" encoding="UTF-8"?>
<financialSummary currency="THB" period="2026-07">
  <cashflow income="25000.00" expense="10900.00" net="14100.00"/>
  <topExpenses>
    <expense category="อาหาร" amount="6500.00" percent="59.6"/>
    <expense category="เดินทาง" amount="3500.00" percent="32.1"/>
  </topExpenses>
  <goals>
    <goal name="เที่ยวญี่ปุ่น" target="50000.00" current="22500.00" progressPct="45"/>
  </goals>
  <alerts>
    <alert level="warning">หมวดเดินทางใช้เกินงบ 500.00 บาท</alert>
  </alerts>
</financialSummary>
```

## subscriptions.xml — รายการสมัครสมาชิก

```xml
<?xml version="1.0" encoding="UTF-8"?>
<subscriptions currency="THB">
  <subscription name="Netflix" amount="419.00" cycle="monthly" nextBilling="2026-08-05"/>
  <subscription name="Spotify" amount="149.00" cycle="monthly" nextBilling="2026-08-12"/>
  <subscription name="iCloud+" amount="35.00" cycle="monthly" nextBilling="2026-08-20"/>
  <total monthly="603.00" yearly="7236.00"/>
</subscriptions>
```
