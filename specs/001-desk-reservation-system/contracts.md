# REST API Contracts

**Feature**: Desk Reservation System  
**Date**: 2026-10-24  
**Ref**: data-model.md, spec.md

---

## Overview

HotDesk exposes a REST API for booking workflows and administrative operations. The API enforces role-based access control (worker vs. admin), returns JSON payloads, and uses standard HTTP status codes.

**Base URL**: `http://localhost:8000/api` (development)

**Authentication**: Mock test users (MVP) → Bearer token in Authorization header
```
Authorization: Bearer <mock-jwt-token>
```

---

## Common Response Format

### Success Response
```json
{
  "success": true,
  "data": { /* response body */ },
  "timestamp": "2026-10-24T15:30:45Z"
}
```

### Error Response
```json
{
  "success": false,
  "error": "Unique constraint violated",
  "message": "Desk already booked for this date",
  "details": {
    "desk_id": 5,
    "reservation_date": "2026-10-25"
  },
  "timestamp": "2026-10-24T15:30:45Z"
}
```

### HTTP Status Codes
- **200 OK**: Successful GET, PATCH, DELETE
- **201 Created**: Successful POST (resource created)
- **400 Bad Request**: Validation error (invalid input, business rule violation)
- **401 Unauthorized**: Missing/invalid authentication token
- **403 Forbidden**: Authenticated but insufficient role (worker accessing admin route)
- **404 Not Found**: Resource not found
- **409 Conflict**: Unique constraint violation (double-booking)
- **500 Internal Server Error**: Unexpected error

---

## Authentication Endpoints

### POST /auth/login

**Description**: Mock login with test username/password. Returns a Bearer token.

**Access**: Public (no auth required)

**Request**:
```json
{
  "email": "alice@company.com",
  "password": "dev-password"
}
```

**Response (200 OK)**:
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 1,
      "email": "alice@company.com",
      "name": "Alice Smith",
      "role": "worker"
    }
  }
}
```

**Response (401 Unauthorized)**:
```json
{
  "success": false,
  "error": "Invalid credentials",
  "message": "Email or password incorrect"
}
```

**Test Users (MVP)**:
- `alice@company.com` / `dev-password` → role: worker
- `bob@company.com` / `dev-password` → role: worker
- `admin@company.com` / `admin-password` → role: admin

---

## Desk Availability Endpoints

### GET /desks

**Description**: List all desks grouped by floor, with availability status for a selected date. Inactive desks excluded.

**Access**: Authenticated (any role)

**Query Parameters**:
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| date | string (ISO 8601) | Yes | Reservation date (e.g., "2026-10-25") |

**Example Request**:
```
GET /desks?date=2026-10-25
Authorization: Bearer <token>
```

**Response (200 OK)**:
```json
{
  "success": true,
  "data": [
    {
      "floor_id": 1,
      "floor_name": "Floor 1 - Finance",
      "floor_number": 1,
      "desks": [
        {
          "id": 1,
          "desk_number": "1",
          "status": "available",
          "booked_by": null,
          "booked_by_name": null
        },
        {
          "id": 2,
          "desk_number": "2",
          "status": "reserved",
          "booked_by": "alice@company.com",
          "booked_by_name": "Alice Smith"
        }
      ]
    },
    {
      "floor_id": 2,
      "floor_name": "Floor 2 - Marketing",
      "floor_number": 2,
      "desks": [
        {
          "id": 10,
          "desk_number": "1",
          "status": "available",
          "booked_by": null,
          "booked_by_name": null
        }
      ]
    }
  ]
}
```

**Response (400 Bad Request - Invalid Date)**:
```json
{
  "success": false,
  "error": "Invalid date format",
  "message": "Date must be ISO 8601 format (YYYY-MM-DD)"
}
```

---

## Reservation Endpoints

### POST /reservations

**Description**: Create a new desk reservation for the authenticated user. Enforces: (1) one active reservation per worker per day, (2) no double-booking of desks, (3) only future/today dates allowed.

**Access**: Authenticated (worker or admin role)

**Request Body**:
```json
{
  "desk_id": 5,
  "reservation_date": "2026-10-25"
}
```

**Response (201 Created)**:
```json
{
  "success": true,
  "data": {
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
    "created_at": "2026-10-24T15:30:45Z"
  }
}
```

**Response (400 Bad Request - User Already Has Reservation This Day)**:
```json
{
  "success": false,
  "error": "Business rule violation",
  "message": "You already have a desk reserved for this date"
}
```

**Response (400 Bad Request - Desk Inactive)**:
```json
{
  "success": false,
  "error": "Desk unavailable",
  "message": "This desk is no longer available for booking"
}
```

**Response (400 Bad Request - Past Date)**:
```json
{
  "success": false,
  "error": "Invalid date",
  "message": "Cannot book a desk for a past date"
}
```

**Response (409 Conflict - Double-Booking)**:
```json
{
  "success": false,
  "error": "Desk already booked",
  "message": "This desk was booked while you were viewing. Please select another desk."
}
```

---

### GET /reservations

**Description**: List all reservations for the authenticated user (upcoming and past). Grouped by upcoming/past, sorted by date descending.

**Access**: Authenticated (any role); users see only their own reservations. Admins can optionally filter by user_id (see query params).

**Query Parameters** (optional):
| Param | Type | Required | Access | Description |
|-------|------|----------|--------|-------------|
| user_id | integer | No | Admin only | Filter by specific user ID (admin feature) |
| filter | string | No | Any | "upcoming" or "past"; default: "all" |

**Example Request**:
```
GET /reservations
Authorization: Bearer <token>
```

**Response (200 OK)**:
```json
{
  "success": true,
  "data": {
    "upcoming": [
      {
        "id": 42,
        "desk_id": 5,
        "desk_number": "5",
        "floor_id": 1,
        "floor_name": "Floor 1 - Finance",
        "reservation_date": "2026-10-25",
        "status": "active",
        "display_status": "Active",
        "is_cancelable": true,
        "created_at": "2026-10-24T15:30:45Z"
      }
    ],
    "past": [
      {
        "id": 40,
        "desk_id": 3,
        "desk_number": "3",
        "floor_id": 1,
        "floor_name": "Floor 1 - Finance",
        "reservation_date": "2026-10-23",
        "status": "active",
        "display_status": "Completed",
        "is_cancelable": false,
        "created_at": "2026-10-23T10:00:00Z"
      },
      {
        "id": 39,
        "desk_id": 2,
        "desk_number": "2",
        "floor_id": 1,
        "floor_name": "Floor 1 - Finance",
        "reservation_date": "2026-10-22",
        "status": "canceled",
        "display_status": "Canceled",
        "is_cancelable": false,
        "canceled_at": "2026-10-22T14:00:00Z"
      }
    ]
  }
}
```

---

### DELETE /reservations/{reservation_id}

**Description**: Cancel an upcoming reservation. Only the owner (or admin) can cancel. Past reservations are not cancelable.

**Access**: Authenticated; user must own the reservation or have admin role

**Path Parameters**:
| Param | Type | Description |
|-------|------|-------------|
| reservation_id | integer | Reservation ID to cancel |

**Example Request**:
```
DELETE /reservations/42
Authorization: Bearer <token>
```

**Response (200 OK)**:
```json
{
  "success": true,
  "data": {
    "id": 42,
    "status": "canceled",
    "display_status": "Canceled",
    "canceled_at": "2026-10-24T15:35:00Z",
    "message": "Reservation canceled. Desk is now available for others."
  }
}
```

**Response (400 Bad Request - Past Date Not Cancelable)**:
```json
{
  "success": false,
  "error": "Cannot cancel past reservation",
  "message": "Only upcoming reservations can be canceled"
}
```

**Response (403 Forbidden - Not Owner)**:
```json
{
  "success": false,
  "error": "Access denied",
  "message": "You can only cancel your own reservations"
}
```

**Response (404 Not Found)**:
```json
{
  "success": false,
  "error": "Reservation not found"
}
```

---

## Admin: Desk Management Endpoints

### POST /admin/desks

**Description**: Create a new desk. Admin only.

**Access**: Admin role required

**Request Body**:
```json
{
  "desk_number": "5",
  "floor_id": 1
}
```

**Response (201 Created)**:
```json
{
  "success": true,
  "data": {
    "id": 5,
    "desk_number": "5",
    "floor_id": 1,
    "active": true,
    "created_at": "2026-10-24T15:30:45Z"
  }
}
```

**Response (400 Bad Request - Duplicate Desk Number on Floor)**:
```json
{
  "success": false,
  "error": "Unique constraint violated",
  "message": "A desk with number '5' already exists on this floor"
}
```

**Response (403 Forbidden - Not Admin)**:
```json
{
  "success": false,
  "error": "Access denied",
  "message": "Only administrators can manage desks"
}
```

---

### PATCH /admin/desks/{desk_id}

**Description**: Update desk properties (desk_number, floor_id). Admin only.

**Access**: Admin role required

**Request Body** (partial):
```json
{
  "desk_number": "5",
  "floor_id": 1
}
```

**Response (200 OK)**:
```json
{
  "success": true,
  "data": {
    "id": 5,
    "desk_number": "5",
    "floor_id": 1,
    "active": true
  }
}
```

---

### DELETE /admin/desks/{desk_id}

**Description**: Deactivate a desk (soft delete). Existing reservations remain in history; new bookings rejected. Admin only.

**Access**: Admin role required

**Example Request**:
```
DELETE /admin/desks/5
Authorization: Bearer <admin-token>
```

**Response (200 OK)**:
```json
{
  "success": true,
  "data": {
    "id": 5,
    "active": false,
    "message": "Desk deactivated. Existing reservations preserved."
  }
}
```

---

## Admin: Floor Management Endpoints

### POST /admin/floors

**Description**: Create a new floor. Admin only.

**Access**: Admin role required

**Request Body**:
```json
{
  "floor_name": "Floor 1 - Finance",
  "floor_number": 1
}
```

**Response (201 Created)**:
```json
{
  "success": true,
  "data": {
    "id": 1,
    "floor_name": "Floor 1 - Finance",
    "floor_number": 1,
    "active": true,
    "created_at": "2026-10-24T15:30:45Z"
  }
}
```

**Response (400 Bad Request - Duplicate Floor Number)**:
```json
{
  "success": false,
  "error": "Unique constraint violated",
  "message": "Floor number 1 already exists"
}
```

---

### PATCH /admin/floors/{floor_id}

**Description**: Update floor properties (floor_name, floor_number). Admin only.

**Access**: Admin role required

**Request Body** (partial):
```json
{
  "floor_name": "Floor 1 - Engineering"
}
```

**Response (200 OK)**:
```json
{
  "success": true,
  "data": {
    "id": 1,
    "floor_name": "Floor 1 - Engineering",
    "floor_number": 1,
    "active": true
  }
}
```

---

### DELETE /admin/floors/{floor_id}

**Description**: Deactivate a floor (soft delete). Desks on floor inherit inactive state. Admin only.

**Access**: Admin role required

**Response (200 OK)**:
```json
{
  "success": true,
  "data": {
    "id": 1,
    "active": false,
    "message": "Floor deactivated."
  }
}
```

---

## Admin: User Management Endpoints

### GET /admin/users

**Description**: List all users with roles and active status. Admin only.

**Access**: Admin role required

**Query Parameters** (optional):
| Param | Type | Description |
|-------|------|-------------|
| role | string | Filter by role: "worker" or "admin" |
| active | boolean | Filter by active status: true or false |

**Example Request**:
```
GET /admin/users?role=worker
Authorization: Bearer <admin-token>
```

**Response (200 OK)**:
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "email": "alice@company.com",
      "name": "Alice Smith",
      "role": "worker",
      "active": true,
      "created_at": "2026-10-24T10:00:00Z"
    },
    {
      "id": 2,
      "email": "bob@company.com",
      "name": "Bob Jones",
      "role": "worker",
      "active": true,
      "created_at": "2026-10-24T10:00:00Z"
    }
  ]
}
```

---

### PATCH /admin/users/{user_id}

**Description**: Update user properties (name, role, active status). Admin only.

**Access**: Admin role required

**Request Body** (partial):
```json
{
  "role": "admin",
  "active": false
}
```

**Response (200 OK)**:
```json
{
  "success": true,
  "data": {
    "id": 1,
    "email": "alice@company.com",
    "name": "Alice Smith",
    "role": "admin",
    "active": false
  }
}
```

---

## Admin: Occupancy Endpoints

### GET /admin/occupancy

**Description**: View all desk reservations for a selected date, grouped by floor. Admin only.

**Access**: Admin role required

**Query Parameters**:
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| date | string (ISO 8601) | Yes | Date to view occupancy (e.g., "2026-10-25") |

**Example Request**:
```
GET /admin/occupancy?date=2026-10-25
Authorization: Bearer <admin-token>
```

**Response (200 OK)**:
```json
{
  "success": true,
  "data": {
    "date": "2026-10-25",
    "occupancy_summary": {
      "total_desks": 15,
      "booked_desks": 5,
      "available_desks": 10,
      "occupancy_rate": 33.3
    },
    "floors": [
      {
        "floor_id": 1,
        "floor_name": "Floor 1 - Finance",
        "desks": [
          {
            "id": 1,
            "desk_number": "1",
            "status": "reserved",
            "booked_by_email": "alice@company.com",
            "booked_by_name": "Alice Smith"
          },
          {
            "id": 2,
            "desk_number": "2",
            "status": "available"
          }
        ]
      }
    ]
  }
}
```

---

## Error Handling

All endpoints return structured error responses with:
- `success: false`
- `error`: Short error code (e.g., "Unique constraint violated")
- `message`: User-friendly message (e.g., "Desk already booked for this date")
- `details` (optional): Additional context (e.g., which field failed validation)

**Standard Error Scenarios**:

| HTTP Status | Error Code | Message | Cause |
|-------------|-----------|---------|-------|
| 400 | business_rule_violation | You already have a desk reserved for this date | User tries 2nd booking same day |
| 400 | desk_unavailable | This desk is no longer available for booking | Desk inactive |
| 400 | invalid_date | Cannot book a desk for a past date | Past date booking attempt |
| 409 | desk_already_booked | This desk was booked while you were viewing. Please select another desk. | Double-booking race condition |
| 403 | access_denied | Only administrators can manage desks | Non-admin tries admin endpoint |
| 404 | not_found | Reservation not found | Invalid reservation ID |
| 500 | internal_error | An unexpected error occurred | Server error |

---

## Rate Limiting

Not implemented for MVP (local dev only). Consider adding in production.

---

## CORS & Security Headers

**CORS Policy** (development):
```
Access-Control-Allow-Origin: http://localhost:3000
Access-Control-Allow-Methods: GET, POST, PATCH, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
Access-Control-Allow-Credentials: true
```

**Security Headers** (to add post-MVP):
- X-Frame-Options: DENY
- X-Content-Type-Options: nosniff
- X-XSS-Protection: 1; mode=block

---

**API Contract Status**: ✅ Complete and ready for frontend integration

**Next Artifact**: TypeScript types definition file (data-model-types.ts)
