# ERD — Multi-tenant AI Assistant (ดีไซน์ใหม่)

> ⚠️ **นี่คือ schema ดีไซน์ใหม่ (target)** ยังไม่ตรงกับ `backend/prisma/schema.prisma` ปัจจุบัน (ดู [database-erd.md](database-erd.md) สำหรับของจริงตอนนี้)
> ไฟล์นี้ทำจากแผนภาพที่ตกลงกันไว้ เพื่อส่งต่อให้แตงกวาลงมือทำ
>
> แก้ไข: พิมพ์แก้ในบล็อก ```mermaid ได้เลย · GitHub / VS Code (Markdown Preview Mermaid) render ให้อัตโนมัติ
> ชนิดข้อมูล/PK/FK บางส่วนเป็นการ **เดาจากชื่อฟิลด์** — ปรับได้ตามจริง

```mermaid
erDiagram
    tenant   ||--o{ customer     : "has"
    customer ||--o{ conversation : "has"
    customer ||--o{ order        : "has"
    customer ||--o{ lead         : "has"
    customer ||--o{ booking      : "has"
    users    ||--o{ audit_log    : "writes"
    order    ||--o{ processed_slip   : "has"
    prompt_variants ||--o{ llm_calls : "used_by"

    tenant {
        string id       PK "ร้าน / โฟลเดอร์"
        string name
        string plan     "free | pro | ..."
        json   persona
        json   products
        json   channels
        json   settings
    }

    customer {
        string user_id   PK
        string tenant_id FK
        string channel   "line | fb | ig | ..."
        string name
        string phone
        int    total_spent
        int    orders
        string tags
    }

    users {
        string id        PK
        string tenant_id FK
        string name
        string role
        string token
    }

    conversation {
        string   id        PK
        string   tenant_id FK
        string   user_id   FK
        string   role      "user | assistant"
        string   content
        datetime ts
    }

    order {
        string   id      PK
        string   user_id FK
        json     items
        int      total
        string   contact
        string   status
        datetime ts
    }

    lead {
        string id      PK
        string user_id FK
        string name
        string phone
        string interest
        string status
    }

    booking {
        string   id       PK
        string   user_id  FK
        string   service
        datetime when
        string   at
        boolean  reminded
        string   status
    }

    audit_log {
        string   id     PK
        string   userId FK "อ้าง users"
        string   actor
        string   role
        string   action
        string   detail
        datetime ts
    }

    processed_slip {
        string ref      PK
        string order_id FK
        int    amount
    }

    prompt_variants {
        string id        PK
        string tenant_id FK
        string name
        string override
        float  weight
    }

    llm_calls {
        string  id         PK
        string  variant_id FK "อ้าง prompt_variants"
        string  provider
        string  model
        int     cost
        float   confidence
        string  variant
    }
```

## ความสัมพันธ์ที่วาดไว้ (ตามแผนภาพ)

| จาก | ถึง | ชนิด |
|-----|-----|------|
| tenant | customer | 1 : N |
| customer | conversation | 1 : N |
| customer | order | 1 : N |
| customer | lead | 1 : N |
| customer | booking | 1 : N |
| users | audit_log | 1 : N |
| order | processed_slip | 1 : N |
| prompt_variants | llm_calls | 1 : N |

## หมายเหตุ (ยังไม่ได้วาดเส้น แต่มี field อ้างถึง)

- `users.tenant_id`, `conversation.tenant_id`, `prompt_variants.tenant_id` → อ้าง `tenant` (implied FK)
- ถ้าจะให้ครบ อาจเพิ่มเส้น `tenant 1:N users`, `tenant 1:N prompt_variants` ได้
