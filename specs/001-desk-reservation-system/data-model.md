# Data Model Design

**Feature**: Desk Reservation System  
**Date**: 2026-10-24  
**Ref**: plan.md, spec.md

---

## Overview

The HotDesk data model consists of four core entities: **User**, **Floor**, **Desk**, and **Reservation**. The model enforces booking safety via unique constraints at the database layer and state transition rules at the application layer.

---

## Entity Definitions

### User

**Purpose**: Represents an employee or administrator using the system.

**Fields**:
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID/Integer | PRIMARY KEY | Unique user identifier |
| email | String(255) | UNIQUE, NOT NULL | User email (unique, used for display) |
| name | String(255) | NOT NULL | Full name |
| role | Enum | NOT NULL, Default: "worker" | "worker" or "admin" |
| active | Boolean | NOT NULL, Default: True | Active users can log in; deactivated users cannot |
| created_at | DateTime | NOT NULL, Default: NOW() | Account creation timestamp |
| updated_at | DateTime | NOT NULL, Default: NOW() | Last update timestamp |

**State Transitions**:
- Created: `active=True, role="worker"` (default) or `role="admin"` (set by admin)
- Deactivated: `active=False` (admin sets; existing reservations remain in history)
- Reactivated: `active=True` (admin sets)

**Constraints**:
- Email uniqueness enforced at DB level: `UNIQUE(email)`
- Role enum: only "worker" or "admin" allowed
- Cannot delete users; only deactivate to preserve history

**Validation Rules**:
- Email: valid format (RFC 5322 subset)
- Name: non-empty, <=255 characters
- Role: case-insensitive enum check

---

### Floor

**Purpose**: Represents a physical floor in the office building.

**Fields**:
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID/Integer | PRIMARY KEY | Unique floor identifier |
| floor_name | String(100) | NOT NULL | Display name (e.g., "Floor 1", "Level 2") |
| floor_number | Integer | NOT NULL, UNIQUE | Floor number for ordering (1, 2, 3...) |
| active | Boolean | NOT NULL, Default: True | Active floors appear in UI; inactive floors hidden |
| created_at | DateTime | NOT NULL, Default: NOW() | Creation timestamp |
| updated_at | DateTime | NOT NULL, Default: NOW() | Last update timestamp |

**State Transitions**:
- Created: `active=True`
- Deactivated: `active=False` (admin sets; desks on this floor inherit state)
- Reactivated: `active=True`

**Constraints**:
- floor_number uniqueness enforced: `UNIQUE(floor_number)` (only one "Floor 1")
- floor_name uniqueness at DB level: `UNIQUE(floor_name)` (friendly names like "Finance Floor" must be distinct)

**Validation Rules**:
- floor_name: non-empty, <=100 characters
- floor_number: positive integer

**Relationships**:
- One-to-Many: Floor → Desk (1 floor has many desks)
- Soft-delete: Desks on inactive floors are hidden from booking UI but history preserved

---

### Desk

**Purpose**: Represents a physical desk in the office that can be reserved.

**Fields**:
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID/Integer | PRIMARY KEY | Unique desk identifier |
| desk_number | String(10) | NOT NULL | Desk number/name within the floor (e.g., "1", "10", "A5") |
| floor_id | UUID/Integer | NOT NULL, FK | Foreign key to Floor |
| active | Boolean | NOT NULL, Default: True | Active desks available for booking; inactive hidden |
| created_at | DateTime | NOT NULL, Default: NOW() | Creation timestamp |
| updated_at | DateTime | NOT NULL, Default: NOW() | Last update timestamp |

**State Transitions**:
- Created: `active=True`
- Deactivated: `active=False` (admin sets; existing reservations remain; no new bookings allowed)
- Reactivated: `active=True`

**Constraints**:
- Composite unique key: `UNIQUE(floor_id, desk_number)` — each floor can have independent Desk 1, Desk 2, etc.
- Foreign key: `floor_id` must exist and correspond to an active Floor
- Cascade behavior: If Floor is deleted, Desks are soft-deleted (active=False), not hard-deleted

**Validation Rules**:
- desk_number: non-empty, <=10 characters (e.g., "1", "10", "A5")
- floor_id: must exist (checked before INSERT)

**Relationships**:
- Many-to-One: Desk → Floor (many desks on 1 floor)
- One-to-Many: Desk → Reservation (1 desk has many reservations across different dates)

**Query Notes**:
- "Available desks for date X": `SELECT * FROM Desk WHERE floor_id = ? AND active = True AND id NOT IN (SELECT desk_id FROM Reservation WHERE reservation_date = ? AND status IN ('active', 'canceled'))`
  - Note: Include canceled reservations in exclusion to avoid re-booking on the same date

---

### Reservation

**Purpose**: Represents a desk booking for a specific date by a worker.

**Fields**:
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID/Integer | PRIMARY KEY | Unique reservation identifier |
| user_id | UUID/Integer | NOT NULL, FK | Foreign key to User (who made the reservation) |
| desk_id | UUID/Integer | NOT NULL, FK | Foreign key to Desk (which desk is reserved) |
| reservation_date | Date | NOT NULL | Date of the reservation (calendar date only, no time) |
| status | Enum | NOT NULL, Default: "active" | "active" or "canceled" (completed is derived, not stored) |
| created_at | DateTime | NOT NULL, Default: NOW() | Reservation creation timestamp |
| canceled_at | DateTime | Nullable | Timestamp when reservation was canceled (NULL if not canceled) |
| updated_at | DateTime | NOT NULL, Default: NOW() | Last update timestamp |

**Status Lifecycle**:
1. **Created**: `status='active', canceled_at=NULL` (if reservation_date >= today)
2. **Viewed as Completed** (implicit): If `reservation_date < today AND status='active'` → treated as "completed" in API responses (not stored)
3. **Canceled**: `status='canceled', canceled_at=<timestamp>` (set when user cancels)
4. **Archive Rule**: All reservations (active, canceled, completed) retained indefinitely for audit trail (FR-012)

**Constraints**:
- Composite unique key: `UNIQUE(desk_id, reservation_date) WHERE status != 'canceled'` — prevents double-booking
  - Rationale: The same desk cannot have two active reservations on the same date; canceled reservations don't count
- Foreign keys: `user_id` and `desk_id` must exist
- Booking guard: `reservation_date >= TODAY()` enforced in application layer (no past-dated bookings)
- Daily limit: Only 1 active reservation per user per day enforced in application layer (before INSERT)

**Validation Rules**:
- reservation_date: must be >= today (system date in office timezone)
- status: only "active" or "canceled"
- user_id: must exist and reference an active User
- desk_id: must exist and reference an active Desk

**Relationships**:
- Many-to-One: Reservation → User (many reservations per user)
- Many-to-One: Reservation → Desk (many reservations per desk, but max 1 per date)

**Derived Attributes** (computed at query time, not stored):
| Attribute | Logic | Example |
|-----------|-------|---------|
| is_upcoming | `reservation_date >= TODAY()` | True if booking is for today or later |
| is_past | `reservation_date < TODAY()` | True if booking was for yesterday or earlier |
| display_status | If `is_past AND status='active'`: "Completed"; If `is_past AND status='canceled'`: "Canceled"; If `is_upcoming AND status='active'`: "Active"; If `is_upcoming AND status='canceled'`: "Canceled" | Determines how UI displays the reservation |
| is_cancelable | `is_upcoming AND status='active'` | Only upcoming active reservations can be canceled |

---

## Validation & Business Rules

### Booking Rules (Enforced at DB + Application Layer)

**FR-003: No Double Bookings**
- Database: UNIQUE constraint on (desk_id, reservation_date, status='active')
- Application: Before INSERT, query for existing active/canceled reservations on that desk-date
- Conflict response: Return 409 with message "Desk already booked for this date" or "Desk was booked while you were viewing"

**FR-004: One Reservation Per Worker Per Day**
- Database: No explicit unique constraint (enforced by application layer for simplicity)
- Application: Before INSERT, query `SELECT COUNT(*) FROM Reservation WHERE user_id=? AND reservation_date=? AND status='active'`
  - If count > 0: return 400 Bad Request with message "You already have a desk reserved for this date"

**FR-009: Inactive Desks Not Bookable**
- Database: Foreign key constraint on desk_id (checks desk exists)
- Application: Before INSERT, check `Desk.active = True`
  - If inactive: return 400 Bad Request with message "This desk is no longer available for booking"

**FR-007: Only Upcoming Reservations Cancelable**
- Database: No constraint (enforced by application logic)
- Application: Before DELETE/UPDATE, check `reservation_date >= TODAY()`
  - If past-dated: return 400 Bad Request with message "Cannot cancel past reservations"

**FR-012: Preserve All History**
- No hard deletes allowed
- Cancellation: Set `status='canceled', canceled_at=NOW()` (soft delete)
- Deactivation: Set `Desk.active=False` (soft delete); existing reservations untouched

---

## Schema Diagram (Text)

```
┌─────────────────────────────────────────────────────────────────┐
│                            USER                                 │
├──────────────┬──────────────┬──────────────┬──────────────────────┤
│ id (PK)      │ email        │ name         │ role (enum)          │
│ active (bool)│ created_at   │ updated_at   │                      │
└──────────────┴──────────────┴──────────────┴──────────────────────┘
      │
      │ (1:N) one user has many reservations
      │
      ├──────────────────────────────────┐
      │                                  │
┌──────────────────────────────────────────────────────────────────┐
│                       RESERVATION                               │
├──────────────┬──────────────┬──────────────┬──────────────────────┤
│ id (PK)      │ user_id (FK) │ desk_id (FK) │ reservation_date    │
│ status (enum)│ canceled_at  │ created_at   │ updated_at          │
│ UNIQUE KEY   │ (desk_id, reservation_date, status != 'canceled') │
└──────────────┴──────────────┴──────────────┴──────────────────────┘
                                    │
                                    │ (N:1) many reservations on one desk
                                    │
                              ┌─────┘
                              │
┌──────────────────────────────────────────────────────────────────┐
│                          DESK                                   │
├──────────────┬──────────────┬──────────────┬──────────────────────┤
│ id (PK)      │ desk_number  │ floor_id (FK)│ active (bool)       │
│ created_at   │ updated_at   │              │                      │
│ UNIQUE KEY   │ (floor_id, desk_number)                            │
└──────────────┴──────────────┴──────────────┴──────────────────────┘
      │
      │ (N:1) many desks on one floor
      │
      └──────────────────┐
                         │
┌──────────────────────────────────────────────────────────────────┐
│                         FLOOR                                   │
├──────────────┬──────────────┬──────────────┬──────────────────────┤
│ id (PK)      │ floor_name   │ floor_number │ active (bool)       │
│ created_at   │ updated_at   │ UNIQUE       │                      │
│ UNIQUE KEY   │ (floor_name)                │                      │
└──────────────┴──────────────┴──────────────┴──────────────────────┘
```

---

## SQLite DDL (Reference)

```sql
CREATE TABLE "user" (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'worker' CHECK(role IN ('worker', 'admin')),
    active BOOLEAN NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE floor (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    floor_name VARCHAR(100) UNIQUE NOT NULL,
    floor_number INTEGER UNIQUE NOT NULL,
    active BOOLEAN NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE desk (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    desk_number VARCHAR(10) NOT NULL,
    floor_id INTEGER NOT NULL,
    active BOOLEAN NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(floor_id) REFERENCES floor(id),
    UNIQUE(floor_id, desk_number)
);

CREATE TABLE reservation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    desk_id INTEGER NOT NULL,
    reservation_date DATE NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'active' CHECK(status IN ('active', 'canceled')),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    canceled_at DATETIME,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES "user"(id),
    FOREIGN KEY(desk_id) REFERENCES desk(id),
    UNIQUE(desk_id, reservation_date) WHERE status != 'canceled'
);

CREATE INDEX idx_reservation_user_date ON reservation(user_id, reservation_date);
CREATE INDEX idx_reservation_desk_date ON reservation(desk_id, reservation_date);
CREATE INDEX idx_desk_floor ON desk(floor_id);
```

---

## Data Integrity & Transactional Guarantees

### Concurrency Control

**Problem**: Two workers simultaneously book the same desk → one must fail.

**Solution**:
1. SQLite with WAL (Write-Ahead Logging) mode enabled for better concurrent read/write
2. SQLAlchemy transaction isolation: `SERIALIZABLE` for booking operations
3. Application-level re-check: Service queries existing reservations immediately before DB INSERT
4. Atomic operation: Full transaction (check + insert) wrapped in single SQLAlchemy session

**Example Flow**:
```
Worker A: POST /reservations { desk_id: 1, date: 2026-10-25 }
  → Service queries: SELECT * FROM reservation WHERE desk_id=1 AND date=2026-10-25 AND status!='canceled'
  → Result: empty (desk is free)
  → BEGIN TRANSACTION
  → INSERT INTO reservation (desk_id, date, status) VALUES (1, 2026-10-25, 'active')
  → COMMIT

Worker B: POST /reservations { desk_id: 1, date: 2026-10-25 } (simultaneously)
  → Service queries: SELECT * (same check, might still see empty due to transaction isolation)
  → BEGIN TRANSACTION
  → INSERT INTO reservation → UNIQUE constraint violation!
  → ROLLBACK
  → Return 409 Conflict: "Desk was booked while you were viewing"
```

### Test Scenarios

- ✅ Normal booking: User books available desk → reservation created
- ✅ Double-booking prevention: Two requests race for same desk → one succeeds, one fails with 409
- ✅ Daily limit: User tries second booking same day → rejected with 400
- ✅ Inactive desk: User tries to book inactive desk → rejected with 400
- ✅ Past date: User tries to book past date → rejected with 400
- ✅ Cancellation: User cancels upcoming reservation → desk becomes available for others

---

## API Representation (JSON Examples)

### User
```json
{
  "id": 1,
  "email": "alice@company.com",
  "name": "Alice Smith",
  "role": "worker",
  "active": true,
  "created_at": "2026-10-24T10:00:00Z",
  "updated_at": "2026-10-24T10:00:00Z"
}
```

### Floor
```json
{
  "id": 1,
  "floor_name": "Floor 1 - Finance",
  "floor_number": 1,
  "active": true,
  "created_at": "2026-10-24T10:00:00Z",
  "updated_at": "2026-10-24T10:00:00Z"
}
```

### Desk (with Availability)
```json
{
  "id": 5,
  "desk_number": "5",
  "floor_id": 1,
  "floor_name": "Floor 1 - Finance",
  "active": true,
  "status": "available",
  "booked_by": null,
  "booked_by_name": null,
  "created_at": "2026-10-24T10:00:00Z",
  "updated_at": "2026-10-24T10:00:00Z"
}
```

### Desk (when Booked)
```json
{
  "id": 5,
  "desk_number": "5",
  "floor_id": 1,
  "floor_name": "Floor 1 - Finance",
  "active": true,
  "status": "reserved",
  "booked_by": "alice@company.com",
  "booked_by_name": "Alice Smith",
  "created_at": "2026-10-24T10:00:00Z",
  "updated_at": "2026-10-24T10:00:00Z"
}
```

### Reservation (Upcoming/Active)
```json
{
  "id": 42,
  "user_id": 1,
  "desk_id": 5,
  "desk_number": "5",
  "floor_id": 1,
  "floor_name": "Floor 1 - Finance",
  "reservation_date": "2026-10-25",
  "status": "active",
  "display_status": "Active",
  "is_upcoming": true,
  "is_cancelable": true,
  "created_at": "2026-10-24T10:00:00Z",
  "canceled_at": null,
  "updated_at": "2026-10-24T10:00:00Z"
}
```

### Reservation (Completed/Past)
```json
{
  "id": 40,
  "user_id": 1,
  "desk_id": 3,
  "desk_number": "3",
  "floor_id": 1,
  "floor_name": "Floor 1 - Finance",
  "reservation_date": "2026-10-23",
  "status": "active",
  "display_status": "Completed",
  "is_upcoming": false,
  "is_cancelable": false,
  "created_at": "2026-10-23T10:00:00Z",
  "canceled_at": null,
  "updated_at": "2026-10-23T10:00:00Z"
}
```

---

**Data Model Status**: ✅ Complete and ready for implementation

**Next Artifact**: `contracts/api-endpoints.md`
