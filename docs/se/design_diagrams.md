# SE-4 Design & Implementation Diagrams

> อ้างอิงจาก implementation จริงใน repo (backend แบบ modular `src/modules/*`, Flutter `lib/features/*`)

## 1. System Architecture Diagram

ภาพรวมสถาปัตยกรรมของระบบ AI Finance Coach "พี่เงิน" แสดงการสื่อสารระหว่าง Layer ทั้งหมด

```mermaid
graph TB
    subgraph Client["📱 Client Layer"]
        Flutter["Flutter App<br/>(Dart + Riverpod + Hive)"]
    end

    subgraph API["⚙️ API Layer (Node.js + Express + TypeScript)"]
        Express["REST API<br/>/api/v1/*"]
        Auth["Auth Middleware<br/>(JWT)"]
        Cache["Cache Layer<br/>(Redis / In-memory fallback)"]
        Router["LLM Provider Router<br/>(coach.ts · OpenAI SDK)"]
        OCRsvc["OCR Service<br/>(coach.ts ocrImage)"]
    end

    subgraph AI["🤖 AI/ML Providers (OpenAI-compatible)"]
        Typhoon["Typhoon LLM + OCR<br/>(ภาษาไทยดีสุด)"]
        Groq["Groq LLM<br/>(เร็ว + ฟรี)"]
        OpenAI["OpenAI GPT<br/>(Fallback)"]
        RuleEngine["Rule-based Reply<br/>(ไม่มี key → grounded)"]
    end

    subgraph DB["🗃️ Data Layer"]
        Prisma["Prisma ORM"]
        SQLite["SQLite (Dev)"]
        Postgres["PostgreSQL (Prod)"]
    end

    subgraph External["🌐 External Services"]
        FCM["Firebase FCM<br/>(Push · guarded)"]
    end

    Flutter <-->|"REST API / JWT"| Express
    Express --> Auth
    Express --> Cache
    Express --> Router
    Express --> OCRsvc
    Express <-->|"Prisma Client"| Prisma
    Prisma --> SQLite
    Prisma --> Postgres
    Router -->|"ลำดับ: มี key ตัวไหนใช้ตัวนั้น"| Typhoon
    Router --> Groq
    Router --> OpenAI
    Router -->|"ทุกตัวล้มเหลว/ไม่มี key"| RuleEngine
    OCRsvc -->|"gmail-style vision"| Typhoon
    Express <-->|"Push Trigger (cron)"| FCM
```

> **หมายเหตุ:** ไม่ได้ใช้ LangChain — การเลือก provider ทำเองใน `backend/src/modules/chat/coach.ts` (`configuredProviders()` + `chatComplete()`) ผ่าน OpenAI SDK ที่ตั้ง `baseURL` ต่างกันต่อ provider · OCR สลิปเป็น **server-side** ด้วย Typhoon OCR (ไม่ใช่ ML Kit บนเครื่อง)

---

## 2. Component Diagram

แสดง Component ทั้งหมดของ Mobile App ฝั่ง Flutter

```mermaid
graph LR
    subgraph Mobile["📱 Flutter App (lib/)"]
        subgraph Presentation["features/ (Presentation)"]
            Auth["auth/<br/>login, register, forgot_password"]
            Dashboard["dashboard/<br/>balance, edit_balance"]
            Transactions["transactions/<br/>add, slip_screen (OCR)"]
            Chat["chat/<br/>chat_screen (AI Coach)"]
            Goals["goals/<br/>goals_screen, deposit"]
            Subs["subscriptions/ · notifications/"]
        end

        subgraph Core["core/ + app/"]
            RouterC["app/router.dart<br/>(go_router)"]
            Theme["app/theme.dart<br/>(Dark + Green)"]
            ApiClient["core/api/api_client.dart<br/>(dio + JWT interceptor + token store)"]
        end

        subgraph State["State (Riverpod)"]
            AuthProvider["authControllerProvider"]
            TxnProvider["dashboardProvider / categoriesProvider"]
            ChatProvider["chatRepoProvider"]
            NotifP["notificationsProvider"]
        end
    end

    Presentation --> State
    State --> ApiClient
    ApiClient <-->|"REST :4000"| Backend[("Backend API")]
```

---

## 3. ER Diagram (จาก Prisma Schema จริง — 9 models)

```mermaid
erDiagram
    User {
        String id PK
        String email UK
        String phone
        String passwordHash "nullable (social login)"
        String provider "local | google | facebook"
        String providerId
        String avatarUrl
        String displayName
        Int monthlyIncome
        Int level
        Int streak
        String deviceToken "FCM"
        DateTime createdAt
        DateTime updatedAt
    }

    Category {
        String id PK
        String name UK
        String nameTh
        String icon
        String color
        String type "income | expense"
        Boolean isDefault
        DateTime createdAt
    }

    Transaction {
        String id PK
        String userId FK
        String type
        Int amount "satang"
        String note
        String source "manual | ocr"
        String categoryId FK
        DateTime occurredAt
        DateTime createdAt
    }

    Budget {
        String id PK
        String userId FK
        String categoryId FK
        Int amount "satang/period"
        String period "monthly | weekly"
        DateTime createdAt
    }

    Goal {
        String id PK
        String userId FK
        String name
        Int target "satang"
        Int current "satang"
        DateTime deadline
        DateTime createdAt
    }

    ChatMessage {
        String id PK
        String userId FK
        String role "user | assistant"
        String content
        String context "JSON: source ของคำตอบ"
        DateTime createdAt
    }

    Notification {
        String id PK
        String userId FK
        String type "budget_near | budget_over | goal | subscription | daily_summary"
        String title
        String body
        Boolean read
        String data "JSON meta"
        DateTime createdAt
    }

    Subscription {
        String id PK
        String userId FK
        String name
        Int amount "satang/รอบ"
        String cycle "monthly | yearly"
        DateTime nextBilling
        String logo
        DateTime createdAt
    }

    Achievement {
        String id PK
        String userId FK
        String type
        DateTime unlockedAt
    }

    User ||--o{ Transaction : "มี"
    User ||--o{ Budget : "ตั้ง"
    User ||--o{ Goal : "วางแผน"
    User ||--o{ ChatMessage : "คุย"
    User ||--o{ Notification : "รับแจ้งเตือน"
    User ||--o{ Subscription : "สมัคร"
    User ||--o{ Achievement : "ได้รับ"
    Category ||--o{ Transaction : "จัดหมวด"
    Category ||--o{ Budget : "กำกับ"
```

---

## 4. UML Class Diagram (Core Domain)

```mermaid
classDiagram
    class User {
        +String id
        +String email
        +String provider
        +String displayName
        +int monthlyIncome
        +int level
        +int streak
        +register() AuthToken
        +login() AuthToken
        +oauthLogin(provider) AuthToken
    }

    class Transaction {
        +String id
        +String userId
        +String type
        +int amount
        +String source
        +String categoryId
        +DateTime occurredAt
        +create() Transaction
        +delete() void
    }

    class Budget {
        +String id
        +int amount
        +String period
        +getStatus() BudgetStatus
    }

    class BudgetStatus {
        +int spent
        +int remaining
        +double percent
        +bool isOverBudget
    }

    class Goal {
        +String id
        +int target
        +int current
        +DateTime deadline
        +getProgress() double
    }

    class LlmProviderRouter {
        +configuredProviders() List~Provider~
        +chatComplete(messages) Reply
        +ocrImage(dataUrl) String
        +note: Typhoon → Groq → OpenAI → rule-based
    }

    class CoachContext {
        +String displayName
        +int monthlyIncome
        +int thisMonthSpent
        +List topExpenses
        +List goals
        +List budgetRemaining
        +int streakDays
    }

    User "1" --> "many" Transaction
    User "1" --> "many" Budget
    User "1" --> "many" Goal
    Budget --> BudgetStatus
    LlmProviderRouter --> CoachContext : ใช้ประกอบ prompt
    CoachContext --> User : สร้างจากข้อมูล (ไม่มี PII)
```

---

## 5. Sequence Diagrams

### 5.1 แชทกับ AI Coach "พี่เงิน" (Context-Aware Chat)

```mermaid
sequenceDiagram
    actor User as ผู้ใช้
    participant Flutter as Flutter App
    participant API as Backend (chat.routes)
    participant DB as Database (Prisma)
    participant AI as LLM Provider Router (coach.ts)

    User->>Flutter: พิมพ์ "เดือนนี้ใช้เงินมากไปไหม?"
    Flutter->>API: POST /api/v1/chat { message } (JWT)
    API->>DB: buildContext(userId) + ดึง history ล่าสุด
    DB-->>API: income, spent, budgets, goals, streak (ไม่มี PII)
    API->>AI: chatComplete(persona + context + message)
    Note over AI: เลือก provider ตาม key ที่ตั้ง<br/>Typhoon → Groq → OpenAI → rule-based
    AI-->>API: คำตอบ (~150–200 คำ + disclaimer ถ้าพูดเรื่องลงทุน)
    API->>DB: บันทึก ChatMessage (role=assistant, source)
    API-->>Flutter: { message, source: "typhoon:..." }
    Flutter-->>User: แสดงฟองแชท + typewriter + Markdown
```

### 5.2 สแกนสลิป (Server-side Typhoon OCR) → บันทึก Transaction

```mermaid
sequenceDiagram
    actor User as ผู้ใช้
    participant Flutter as Flutter App (slip_screen)
    participant API as Backend (transactions.routes)
    participant OCR as Typhoon OCR (coach.ts ocrImage)
    participant Parser as parser.ts
    participant DB as Database

    User->>Flutter: เลือก/ถ่ายรูปสลิป
    Flutter->>API: POST /transactions/parse-slip { imageBase64 } (JWT)
    API->>OCR: ส่งรูป (data URL) ให้ Typhoon OCR
    OCR-->>API: Raw text (ยอด, วันที่, ผู้รับ, อ้างอิง)
    API->>Parser: parseAmount / parseDate / parseMerchant / autoCategorize
    Parser-->>API: { amount, date, merchant, categoryId }
    API-->>Flutter: เติมฟอร์มอัตโนมัติ (ยอด/วันที่/หมวด/คำอธิบาย)
    User->>Flutter: ตรวจสอบและกด "ยืนยัน"
    Flutter->>API: POST /transactions { amount, occurredAt, categoryId, source: "ocr" }
    API->>DB: INSERT Transaction (+ ตรวจ anomaly)
    API-->>Flutter: { transaction, anomalyAlert? }
    Flutter-->>User: กลับหน้าเดิม + invalidate Dashboard
```

### 5.3 ตรวจสอบงบประมาณและแจ้งเตือน

```mermaid
sequenceDiagram
    participant Cron as Cron Job (NOTIF_CRON=on)
    participant API as Backend (triggers.ts)
    participant DB as Database
    participant FCM as Firebase FCM (guarded)
    actor User as ผู้ใช้ (มือถือ)

    Cron->>API: runBudgetTriggers() ตรวจงบทุกผู้ใช้
    API->>DB: คำนวณ spent เทียบ budget
    DB-->>API: หมวดที่ใกล้/เกินงบ
    loop แต่ละหมวดที่เกิน threshold
        API->>DB: สร้าง Notification (budget_near | budget_over)
        API->>FCM: ส่ง push (ถ้ามี deviceToken + creds)
        FCM-->>User: 🔔 "คุณใช้งบอาหารไปแล้ว 85% เดือนนี้!"
    end
    Note over API,User: ถ้ายังไม่ตั้ง Firebase creds → เก็บใน Notification Center อย่างเดียว
```

---

## 6. Wireframe — หน้าจอสำคัญ

### 6.1 หน้า Goals (เป้าหมายการออม) — ทำแล้ว

```
┌─────────────────────────────┐
│ 🎯 เป้าหมายของฉัน           │
├─────────────────────────────┤
│  ✈️ เที่ยวญี่ปุ่น          │
│  [██████████░░░░] 45%       │
│  22,500 / 50,000 บาท        │
│  ครบกำหนด: ธ.ค. 2569        │
├─────────────────────────────┤
│  🏠 ดาวน์คอนโด             │
│  [████░░░░░░░░░░] 25%       │
│  75,000 / 300,000 บาท       │
│  ครบกำหนด: มิ.ย. 2570       │
├─────────────────────────────┤
│     [+ สร้างเป้าหมายใหม่]  │
└─────────────────────────────┘
```

### 6.2 หน้า Gamification (Streak & Badge) — Sprint 6 (ยังไม่ทำ)

```
┌─────────────────────────────┐
│ 🔥 สตรีคปัจจุบัน: 12 วัน  │
│                             │
│  🥉 นักออมหน้าใหม่    ✅   │
│  🥈 บันทึกสม่ำเสมอ    ✅   │
│  🥇 นักวางแผน         🔒   │
│  💎 ปรมาจารย์การเงิน   🔒   │
│                             │
│ 📅 ชาเลนจ์สัปดาห์นี้       │
│  "บันทึกรายจ่าย 7 วันติด" │
│  [████████░░] 4/7 วัน      │
└─────────────────────────────┘
```
