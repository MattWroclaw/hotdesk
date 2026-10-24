# Implementation Tasks: Desk Reservation System

**Feature**: Desk Reservation System (001-desk-reservation-system)  
**Branch**: `001-desk-reservation-system`  
**Date**: 2026-10-24  
**Status**: Ready for Implementation

---

## Overview

This document contains all implementation tasks organized by user story and phase. Tasks are sequenced with dependencies and marked for parallelization where applicable. Each task is independently testable and immediately actionable.

**Total Tasks**: 52 implementation tasks across 7 phases  
**Estimated Scope**: 2-3 weeks for solo developer or 1 week with 2-3 developers  
**MVP Scope**: Phases 1-4 (User Stories 1-3; core booking workflows)

---

## Phase 1: Setup & Project Initialization

**Goal**: Initialize project structure, dependencies, and local development environment  
**Blocking**: All subsequent phases depend on Phase 1 completion

- [ ] T001 Create backend project structure per plan.md: backend/ directory with app/, tests/, requirements.txt, pytest.ini
- [ ] T002 Create frontend project structure per plan.md: frontend/ directory with src/, public/, package.json, tsconfig.json, vitest.config.ts
- [ ] T003 Initialize Python virtual environment and install backend dependencies (FastAPI, SQLAlchemy, Pydantic, python-dateutil)
- [ ] T004 Initialize Node.js/npm and install frontend dependencies (React, React Router, TypeScript, Axios, Testing Library, Vitest)
- [ ] T005 Set up SQLite database file (hotdesk.db) with WAL mode enabled for concurrency support
- [ ] T006 Create backend configuration file (app/config.py) with database path, mock test users, environment settings
- [ ] T007 Create frontend environment configuration (.env.local) with API base URL (http://localhost:8000/api)
- [ ] T008 Set up pytest configuration (backend/pytest.ini) with test discovery, database fixtures
- [ ] T009 Set up Vitest/Jest configuration (frontend/vitest.config.ts) for component testing
- [ ] T010 Create GitHub issue templates and CONTRIBUTING.md with Spec-Driven Development workflow reference

---

## Phase 2: Foundational Infrastructure (Database & Authentication)

**Goal**: Implement core infrastructure needed by all user stories  
**Blocking**: All user story phases depend on Phase 2 completion  
**Independent Test**: Database operations work; mock login returns valid token

### Database Setup

- [ ] T011 [P] Create SQLAlchemy database initialization (app/database.py) with connection pool, session factory, engine configuration
- [ ] T012 [P] Implement User model in app/models/user.py with fields: id (Integer PK), email (String 255 UNIQUE NOT NULL), name (String 255 NOT NULL), role (Enum: 'worker'|'admin', default 'worker'), active (Boolean default True), created_at/updated_at (DateTime)
- [ ] T013 [P] Implement Floor model in app/models/floor.py with fields: id (Integer PK), floor_name (String 100 UNIQUE NOT NULL), floor_number (Integer UNIQUE NOT NULL), active (Boolean default True), created_at/updated_at (DateTime)
- [ ] T014 [P] Implement Desk model in app/models/desk.py with fields: id (Integer PK), desk_number (String 10 NOT NULL), floor_id (Integer FK NOT NULL), active (Boolean default True), created_at/updated_at (DateTime); add UNIQUE constraint (floor_id, desk_number)
- [ ] T015 [P] Implement Reservation model in app/models/reservation.py with fields: id (Integer PK), user_id (Integer FK NOT NULL), desk_id (Integer FK NOT NULL), reservation_date (Date NOT NULL), status (Enum: 'active'|'canceled', default 'active'), created_at/updated_at (DateTime), canceled_at (DateTime nullable); add UNIQUE constraint (desk_id, reservation_date) WHERE status != 'canceled'
- [ ] T016 Create database migration script to create all tables and indexes; run migration to initialize hotdesk.db
- [ ] T017 [P] Create SQLAlchemy model validators for each model ensuring constraints from data-model.md (email format, name non-empty <=255 chars, desk_number <=10 chars, role enum check)

### Authentication & Authorization

- [ ] T018 Implement mock authentication service (app/services/auth_service.py) with hardcoded test users: alice@company.com/dev-password (worker), bob@company.com/dev-password (worker), admin@company.com/admin-password (admin)
- [ ] T019 Create JWT token generation utility (mock, dev-only; not cryptographically secure) in app/services/auth_service.py
- [ ] T020 Implement authentication middleware (app/middleware/auth.py) to validate Bearer token in Authorization header; extract user ID and role
- [ ] T021 Create role-based access control decorator (@require_role) in app/middleware/auth.py for route protection
- [ ] T022 Implement mock login endpoint (POST /auth/login) in app/api/auth.py returning token and user object
- [ ] T023 Create test fixtures (backend/tests/conftest.py) for test users, database session, auth tokens; ensure DB is clean for each test
- [ ] T024 Write integration test for mock login flow: test successful login, invalid credentials, token generation

---

## Phase 3: User Story 1 - Browse Available Desks (P1 Core)

**Goal**: Workers can view available desks grouped by floor for a selected date  
**Independent Test**: GET /desks?date=2026-10-25 returns 200 OK with desks grouped by floor, status (available/reserved), booked_by info  
**Blocked by**: Phase 2 (database, auth)  
**Blocks**: User Story 2 (needs to know desk availability before booking)

### Data & Services

- [ ] T025 [P] [US1] Create DeskSchema (Pydantic) in app/schemas/desk.py with fields: id, desk_number, floor_id, floor_name, status (available/reserved), booked_by (email or null), booked_by_name, created_at
- [ ] T026 [P] [US1] Create availability service method in app/services/availability_service.py: `get_desks_by_floor(date: date) -> List[FloorWithDesks]` returning desks grouped by floor, filtered by active desks only, marking status based on reservations for that date
- [ ] T027 [P] [US1] Create reservation query helper in availability_service.py: `get_reservations_for_date(date: date) -> List[Reservation]` returning all active AND canceled reservations (to mark desk as used even if canceled)
- [ ] T028 [US1] Implement status determination logic (available vs reserved) in availability_service: if desk_id exists in reservations for that date and status='active', mark as reserved; show booked_by user info

### API Endpoints

- [ ] T029 [P] [US1] Create desks API route handler in app/api/desks.py: GET /desks with query param date (ISO 8601), requires auth
- [ ] T030 [US1] Implement GET /desks logic: validate date format, fetch desks via availability_service, return grouped response with 200 OK
- [ ] T031 [US1] Add error handling for GET /desks: return 400 if date format invalid, 401 if auth missing

### Frontend Components

- [ ] T032 [P] [US1] Create DeskGrid component (frontend/src/components/DeskGrid.tsx) rendering desks grouped by floor with visual distinction (CSS class/color) for available vs reserved
- [ ] T033 [P] [US1] Create DeskCard component (frontend/src/components/DeskCard.tsx) showing desk number, status, booked-by name if reserved, clickable for booking
- [ ] T034 [US1] Create BookingPage component (frontend/src/pages/BookingPage.tsx) with date picker, calls GET /desks on date change, displays DeskGrid with DeskCards
- [ ] T035 [P] [US1] Create useDesks hook (frontend/src/hooks/useDesks.ts) to fetch desks via API, manage loading/error state
- [ ] T036 [US1] Implement date picker in BookingPage using native HTML date input, validates date >= today
- [ ] T037 [US1] Add responsive CSS (frontend/src/styles/global.css) for DeskGrid: flex layout for desktop (3+ columns), tablet (2 columns), mobile (1 column)

### Testing

- [ ] T038 [US1] Write unit test for availability_service.get_desks_by_floor: mock Floor/Desk/Reservation data, verify grouping and status assignment
- [ ] T039 [US1] Write integration test for GET /desks endpoint: seed test data, call endpoint, verify response structure and desk grouping
- [ ] T040 [US1] Write component test for DeskGrid.tsx using React Testing Library: render with mock desks, verify floor grouping and desk display
- [ ] T041 [US1] Write E2E test using quickstart.md Scenario 1A: login as alice, GET /desks for today, verify response matches expected structure

---

## Phase 4: User Story 2 - Create Desk Reservation (P1 Core)

**Goal**: Workers can book available desks; system prevents double-bookings and daily limits  
**Independent Test**: POST /reservations with valid desk_id and future date creates reservation with 201; duplicate desk-date returns 409; duplicate user-date returns 400  
**Blocked by**: Phase 2 (auth), Phase 3 (desk availability)  
**Blocks**: User Story 3 (needs working reservations to view/cancel)

### Data & Services

- [ ] T042 [P] [US2] Create ReservationSchema (Pydantic) in app/schemas/reservation.py with fields: id, user_id, desk_id, desk_number, floor_id, floor_name, reservation_date, status, display_status, is_upcoming, is_cancelable, created_at, canceled_at
- [ ] T043 [P] [US2] Implement booking service in app/services/booking_service.py: `create_reservation(user_id: int, desk_id: int, date: date) -> Reservation` with checks:
  - desk_id exists and is active (else raise ValueError "Desk unavailable")
  - date >= today (else raise ValueError "Cannot book past date")
  - user has no active reservation for that date (else raise ValueError "Already reserved")
  - desk has no active reservation for that date (else raise ValueError "Desk booked")
  - INSERT reservation into DB within transaction (SERIALIZABLE isolation)
- [ ] T044 [US2] Implement validation: check Desk.active = True before allowing booking
- [ ] T045 [US2] Implement daily limit validation: SELECT COUNT active reservations for (user_id, date); if > 0, reject
- [ ] T046 [P] [US2] Implement double-booking detection: SELECT active reservations for (desk_id, date); if any exist, reject with 409 Conflict
- [ ] T047 [US2] Add error handling in booking_service to catch SQLAlchemy IntegrityError (UNIQUE constraint violation on desk-date) and convert to 409 Conflict response

### API Endpoints

- [ ] T048 [P] [US2] Create reservations API route handler in app/api/reservations.py: POST /reservations with JSON body {desk_id, reservation_date}, requires auth
- [ ] T049 [US2] Implement POST /reservations logic: validate input via Pydantic, call booking_service.create_reservation, return 201 Created with reservation object
- [ ] T050 [US2] Add error responses for POST /reservations:
  - 400 Bad Request if date invalid format or past date
  - 400 if user already has reservation that day
  - 400 if desk inactive
  - 409 Conflict if desk already booked (concurrent booking)
  - 401 if auth missing

### Frontend Components

- [ ] T051 [P] [US2] Create ReservationForm component (frontend/src/components/ReservationForm.tsx) with desk selection (click DeskCard to select), confirm button, error message display
- [ ] T052 [US2] Integrate form into BookingPage: on DeskCard click, set selected desk, show confirm button; POST /reservations on confirm
- [ ] T053 [P] [US2] Create useReservationCreate hook (frontend/src/hooks/useReservationCreate.ts) calling POST /reservations, handling errors (409 conflict, 400 validation)
- [ ] T054 [US2] Add success notification in BookingPage: show "Reservation created for Desk X on Date Y" after successful POST
- [ ] T055 [US2] Add error notification in BookingPage: show user-friendly error messages mapped from API responses (e.g., "This desk was booked while you were viewing")

### Testing

- [ ] T056 [US2] Write unit test for booking_service.create_reservation: test success path, daily limit rejection, double-booking detection, past date rejection
- [ ] T057 [US2] Write integration test for POST /reservations: seed test data, call endpoint with valid/invalid payloads, verify 201/400/409 responses
- [ ] T058 [US2] Write concurrency test for POST /reservations: simulate two simultaneous requests for same desk-date, verify one succeeds (201), one fails (409)
- [ ] T059 [US2] Write component test for ReservationForm.tsx: render, select desk, submit, verify POST call with correct payload
- [ ] T060 [US2] Write E2E test using quickstart.md Scenario 2A-2C: successful booking, double-booking conflict, daily limit rejection

---

## Phase 5: User Story 3 - View & Cancel Personal Reservations (P1 Core)

**Goal**: Workers can view upcoming/past reservations and cancel only upcoming ones  
**Independent Test**: GET /reservations returns user's upcoming and past reservations; DELETE /reservations/{id} for upcoming works (200), for past fails (400)  
**Blocked by**: Phase 2 (auth), Phase 4 (reservations exist)  
**Blocks**: None (independent completion)

### Data & Services

- [ ] T061 [P] [US3] Create reservation query service in app/services/booking_service.py: `get_user_reservations(user_id: int) -> {upcoming: List, past: List}` separating by reservation_date >= today vs < today
- [ ] T062 [P] [US3] Implement display_status derivation: if is_past and status='active' then "Completed"; if is_past and status='canceled' then "Canceled"; if is_upcoming and status='active' then "Active"; if is_upcoming and status='canceled' then "Canceled"
- [ ] T063 [P] [US3] Implement is_cancelable logic: return True only if is_upcoming AND status='active'
- [ ] T064 [US3] Implement cancellation service in app/services/booking_service.py: `cancel_reservation(reservation_id: int, user_id: int) -> Reservation` with checks:
  - reservation exists (else raise ValueError "Not found")
  - user owns reservation or is admin (else raise PermissionError "Not owner")
  - reservation_date >= today (else raise ValueError "Cannot cancel past")
  - UPDATE reservation SET status='canceled', canceled_at=NOW()

### API Endpoints

- [ ] T065 [P] [US3] Create GET /reservations endpoint in app/api/reservations.py: returns {upcoming: [], past: []} with correct display_status and is_cancelable
- [ ] T066 [US3] Implement admin filter for GET /reservations: allow admin to query user_id param to view other users' reservations; reject if non-admin attempts
- [ ] T067 [P] [US3] Create DELETE /reservations/{reservation_id} endpoint in app/api/reservations.py
- [ ] T068 [US3] Implement DELETE logic: validate user owns reservation, call cancellation_service, return 200 OK
- [ ] T069 [US3] Add error responses for DELETE /reservations:
  - 400 if past-dated reservation (non-cancelable)
  - 403 if user doesn't own reservation
  - 404 if reservation not found

### Frontend Components

- [ ] T070 [P] [US3] Create ReservationList component (frontend/src/components/ReservationList.tsx) showing upcoming and past sections, each with reservation cards
- [ ] T071 [P] [US3] Create ReservationCard component showing desk, date, status, cancel button (visible only if is_cancelable)
- [ ] T072 [US3] Create MyReservationsPage component (frontend/src/pages/MyReservationsPage.tsx) fetching and displaying ReservationList
- [ ] T073 [P] [US3] Create useReservations hook (frontend/src/hooks/useReservations.ts) calling GET /reservations
- [ ] T074 [US3] Implement cancel button handler: calls DELETE /reservations/{id}, refreshes list on success
- [ ] T075 [US3] Add UI feedback: show confirmation dialog before canceling, success message after canceling, error message on failure
- [ ] T076 [US3] Update navigation: add "My Reservations" link in NavBar visible to all authenticated users

### Testing

- [ ] T077 [US3] Write unit test for booking_service.get_user_reservations: mock data, verify upcoming/past separation, display_status assignment
- [ ] T078 [US3] Write unit test for booking_service.cancel_reservation: test success, past date rejection, non-owner rejection
- [ ] T079 [US3] Write integration test for GET /reservations: seed data, call endpoint, verify upcoming/past grouping
- [ ] T080 [US3] Write integration test for DELETE /reservations: test success (200), past date (400), non-owner (403)
- [ ] T081 [US3] Write component test for ReservationList.tsx: render with mock data, verify sections, cancel button visibility
- [ ] T082 [US3] Write E2E test using quickstart.md Scenario 3A-3C: view reservations, cancel upcoming, verify past not cancelable

---

## Phase 6: User Story 4 - Manage Desks & Floors (P2 Admin)

**Goal**: Admins can add/edit/deactivate desks and floors  
**Independent Test**: POST /admin/desks and /admin/floors create resources (201); PATCH updates; DELETE deactivates (200)  
**Blocked by**: Phase 2 (auth with role enforcement)  
**Blocks**: None for MVP (P2 feature)

### Data & Services

- [ ] T083 [P] [US4] Create FloorSchema and DeskSchema (Pydantic) in app/schemas/desk.py for admin endpoints with all fields including active status
- [ ] T084 [US4] Implement floor/desk CRUD services in app/services/desk_service.py:
  - `create_floor(floor_name, floor_number) -> Floor` (verify unique floor_number, floor_name)
  - `create_desk(desk_number, floor_id) -> Desk` (verify floor exists, desk_number not already in (floor_id, desk_number))
  - `update_desk(desk_id, desk_number=None, floor_id=None) -> Desk`
  - `deactivate_desk(desk_id) -> Desk` (set active=False; preserve existing reservations)
  - `deactivate_floor(floor_id) -> Floor` (set active=False; cascade to all desks on floor)

### API Endpoints

- [ ] T085 [P] [US4] Create admin desks API (app/api/admin_desks.py) with routes:
  - POST /admin/desks (create) → @require_role("admin")
  - PATCH /admin/desks/{desk_id} (update) → @require_role("admin")
  - DELETE /admin/desks/{desk_id} (deactivate) → @require_role("admin")
- [ ] T086 [P] [US4] Create admin floors API (app/api/admin_floors.py) with routes:
  - POST /admin/floors (create) → @require_role("admin")
  - PATCH /admin/floors/{floor_id} (update) → @require_role("admin")
  - DELETE /admin/floors/{floor_id} (deactivate) → @require_role("admin")
- [ ] T087 [US4] Implement POST /admin/desks logic: validate input, call create_desk, return 201 with desk object
- [ ] T088 [US4] Add error handling: 400 if desk_number already exists on floor (unique constraint violation); 403 if non-admin
- [ ] T089 [US4] Implement PATCH /admin/desks and PATCH /admin/floors with update logic
- [ ] T090 [US4] Implement DELETE logic: soft delete (set active=False), preserve history, return 200

### Frontend Components

- [ ] T091 [P] [US4] Create AdminDesksMgmt component (frontend/src/pages/AdminDesksMgmt.tsx) with floor/desk list, add/edit/delete buttons
- [ ] T092 [P] [US4] Create AddDeskForm component (frontend/src/components/AddDeskForm.tsx) with desk_number input, floor selector, submit button
- [ ] T093 [US4] Create AdminFloorsMgmt component (frontend/src/pages/AdminFloorsMgmt.tsx) with floor list, add/edit/delete buttons
- [ ] T094 [US4] Integrate admin pages into navigation: add "Admin Panel" in NavBar visible only to admin users
- [ ] T095 [US4] Implement API calls for desk/floor CRUD via admin service (frontend/src/services/adminService.ts)
- [ ] T096 [US4] Add confirmation dialogs for deactivation actions

### Testing

- [ ] T097 [US4] Write unit test for desk_service CRUD methods: test create, update, deactivate operations
- [ ] T098 [US4] Write integration test for POST /admin/desks: test success, unique constraint violation (400), non-admin access (403)
- [ ] T099 [US4] Write integration test for DELETE /admin/desks: verify soft delete, history preserved
- [ ] T100 [US4] Write component test for AdminDesksMgmt.tsx: render, test add/edit/delete button interactions
- [ ] T101 [US4] Write E2E test using quickstart.md Scenario 4A-4B: admin creates floor, adds desks, deactivates desk

---

## Phase 7: User Story 5 - Manage Users & Permissions (P2 Admin)

**Goal**: Admins can manage user accounts, assign roles, deactivate users  
**Independent Test**: GET /admin/users returns list; PATCH /admin/users/{id} changes role/status (200); workers cannot access (403)  
**Blocked by**: Phase 2 (auth with role enforcement)  
**Blocks**: None for MVP (P2 feature)

### Data & Services

- [ ] T102 [P] [US5] Create UserSchema (Pydantic) in app/schemas/user.py for admin endpoints with all fields
- [ ] T103 [US5] Implement user management services in app/services/user_service.py:
  - `get_all_users() -> List[User]`
  - `update_user_role(user_id, role) -> User` (validate role enum)
  - `deactivate_user(user_id) -> User` (set active=False; preserve reservation history)
  - `reactivate_user(user_id) -> User` (set active=True)

### API Endpoints

- [ ] T104 [P] [US5] Create admin users API (app/api/admin_users.py) with routes:
  - GET /admin/users → @require_role("admin") with optional filters (role, active)
  - PATCH /admin/users/{user_id} → @require_role("admin")
- [ ] T105 [US5] Implement GET /admin/users: return list of all users with role and active status
- [ ] T106 [US5] Implement filtering in GET /admin/users: allow role and active query params
- [ ] T107 [US5] Implement PATCH /admin/users/{user_id}: update role and active status, return 200
- [ ] T108 [US5] Add error handling: 403 if non-admin, 404 if user not found

### Frontend Components

- [ ] T109 [P] [US5] Create AdminUsersMgmt component (frontend/src/pages/AdminUsersMgmt.tsx) with user list, role selector dropdown, deactivate button
- [ ] T110 [US5] Implement user filtering UI: checkboxes for role filter and active status filter
- [ ] T111 [US5] Create role change handler: calls PATCH /admin/users on role change, shows success/error feedback
- [ ] T112 [US5] Implement deactivate user action with confirmation dialog
- [ ] T113 [US5] Add frontend service calls in adminService.ts for user management

### Testing

- [ ] T114 [US5] Write integration test for GET /admin/users: test full list, role filter, active filter
- [ ] T115 [US5] Write integration test for PATCH /admin/users: test role change, deactivation, non-admin access (403)
- [ ] T116 [US5] Write component test for AdminUsersMgmt.tsx: render list, test role dropdown, deactivate button
- [ ] T117 [US5] Write E2E test using quickstart.md Scenario (admin user management): list users, change role, deactivate user

---

## Phase 8: User Story 6 - View Office Occupancy (P3 Admin)

**Goal**: Admins can view desk occupancy for any date  
**Independent Test**: GET /admin/occupancy?date=2026-10-25 returns occupancy summary and desk list (200); workers cannot access (403)  
**Blocked by**: Phase 2 (auth), Phase 4 (reservations)  
**Blocks**: None for MVP (P3 feature)

### Data & Services

- [ ] T118 [P] [US6] Create occupancy query service in app/services/occupancy_service.py:
  - `get_occupancy_for_date(date: date) -> {summary, floors_with_desks}` calculating:
    - total_desks (active desks count)
    - booked_desks (active reservations count)
    - available_desks (total - booked)
    - occupancy_rate (booked / total * 100)
    - floors with desk details (desk_number, status, booked_by info)

### API Endpoints

- [ ] T119 [P] [US6] Create admin occupancy API (app/api/admin_occupancy.py) with route:
  - GET /admin/occupancy (requires query param: date) → @require_role("admin")
- [ ] T120 [US6] Implement GET /admin/occupancy logic: validate date, call occupancy_service, return 200 with occupancy data
- [ ] T121 [US6] Add error handling: 400 if date format invalid, 403 if non-admin

### Frontend Components

- [ ] T122 [P] [US6] Create AdminOccupancy component (frontend/src/pages/AdminOccupancy.tsx) with date picker, occupancy summary (total, booked, available, rate %), desk list grouped by floor
- [ ] T123 [US6] Create OccupancySummary component displaying metrics
- [ ] T124 [US6] Implement date picker with default = today, calls GET /admin/occupancy on change
- [ ] T125 [US6] Add admin navigation link for occupancy view

### Testing

- [ ] T126 [US6] Write unit test for occupancy_service: mock desks and reservations, verify metrics calculation
- [ ] T127 [US6] Write integration test for GET /admin/occupancy: seed data, call endpoint, verify response structure
- [ ] T128 [US6] Write component test for AdminOccupancy.tsx: render with mock data, verify summary display
- [ ] T129 [US6] Write E2E test using quickstart.md Scenario 5: admin views occupancy

---

## Phase 9: Polish & Cross-Cutting Concerns

**Goal**: Finalize error handling, validation, logging, security headers, documentation  
**Independent Test**: All endpoints return proper error responses; logging functional; UI responsive on mobile

### Error Handling & Validation

- [ ] T130 [P] Create global error handler middleware in app/middleware/error_handler.py converting exceptions to standard error responses
- [ ] T131 [P] Implement comprehensive input validation: all Pydantic schemas validate constraints from data-model.md (email format, string lengths, required fields)
- [ ] T132 [P] Add 404 handling: return structured error response for non-existent routes

### Logging & Monitoring

- [ ] T133 [P] Configure logging in backend (app/config.py): log all HTTP requests, errors, database operations
- [ ] T134 [P] Add request/response logging middleware: log method, path, status, user (if authenticated), timestamp
- [ ] T135 Create logs directory and configure log file rotation

### Security & Headers

- [ ] T136 [P] Add CORS middleware (app/main.py) allowing http://localhost:3000 for development
- [ ] T137 Add security headers (X-Frame-Options, X-Content-Type-Options, X-XSS-Protection) via middleware
- [ ] T138 Implement HTTPS redirect for production (document for deployment phase)

### Frontend Polish

- [ ] T139 [P] Add global error boundary (frontend/src/components/ErrorBoundary.tsx) catching React component errors
- [ ] T140 [P] Create NotificationContext for success/error messages with auto-dismiss
- [ ] T141 Add loading spinners to async operations (desks fetch, reservation create, cancellation)
- [ ] T142 Implement 401 error handling (redirect to login on auth token expiry)
- [ ] T143 Add empty state messaging (no desks, no reservations, etc.)

### Documentation & README

- [ ] T144 Write backend README.md: setup instructions, running tests, API documentation link
- [ ] T145 Write frontend README.md: setup instructions, environment variables, running tests
- [ ] T146 Create TESTING.md documenting how to run tests, expected test structure, coverage requirements
- [ ] T147 Create API_TESTING.md with curl/Postman examples for all endpoints
- [ ] T148 Document mock auth setup and test users in API_TESTING.md
- [ ] T149 Create ARCHITECTURE.md documenting tech stack, design decisions, folder structure

### Performance & Optimization

- [ ] T150 [P] Add database query indexing: CREATE INDEX idx_reservation_user_date, idx_reservation_desk_date, idx_desk_floor (optimize common queries)
- [ ] T151 [P] Implement pagination for GET endpoints (limit, offset query params) for future scalability
- [ ] T152 Add query result caching for availability queries (if performance tests show need)

### Final Integration Testing

- [ ] T153 Run full quickstart.md test suite manually (all 12 scenarios) to verify end-to-end workflows
- [ ] T154 Run concurrent booking test (Scenario: Concurrent Booking) to verify concurrency safety
- [ ] T155 Verify responsive design on mobile (375px), tablet (768px), desktop (1024px+)
- [ ] T156 Run all backend tests: pytest (all phases) coverage >= 80% for booking logic
- [ ] T157 Run all frontend tests: Vitest (component tests) coverage for critical components
- [ ] T158 Verify no console errors or warnings in browser dev tools

---

## Dependency Graph & Execution Strategy

### Critical Path (Sequential Dependencies)
```
Phase 1: Setup
  ↓
Phase 2: Foundational (Database + Auth)
  ├→ Phase 3: US1 (Browse Desks) - depends on Phase 2
  │   ↓
  │   Phase 4: US2 (Create Reservation) - depends on Phase 2 + Phase 3
  │   ↓
  │   Phase 5: US3 (View & Cancel) - depends on Phase 2 + Phase 4
  │
  ├→ Phase 6: US4 (Manage Desks) - depends on Phase 2 only (parallel with 3-5)
  │
  ├→ Phase 7: US5 (Manage Users) - depends on Phase 2 only (parallel with 3-6)
  │
  └→ Phase 8: US6 (Occupancy) - depends on Phase 2 + Phase 4 (parallel with 5-7)
      ↓
Phase 9: Polish & Integration Testing
```

### Parallelization Opportunities

**Within Phase 2**: T011-T015 (models) can be built in parallel  
**Within Phase 3**: T025-T030 (backend) parallel with T032-T037 (frontend)  
**Within Phase 4**: T042-T048 (backend) parallel with T051-T055 (frontend)  
**Within Phase 5**: T061-T068 (backend) parallel with T070-T076 (frontend)  
**Phases 3-5 vs 6-8**: Core workflow (P1 stories) can proceed while admin features (P2-P3) are developed in parallel after Phase 2

### Solo Developer Timeline

- Phase 1: 2-3 hours (setup)
- Phase 2: 4-5 hours (foundational)
- Phase 3: 3-4 hours
- Phase 4: 4-5 hours
- Phase 5: 3-4 hours
- **Phases 3-5 (Core MVP)**: 10-13 hours cumulative
- Phases 6-8: 8-10 hours (can develop in parallel after Phase 2)
- Phase 9: 3-4 hours (polish)
- **Total Estimate**: 25-35 hours (3-4 working days full-time)

### Team of 2-3 Developers

- Phase 1: 1-2 hours (one person)
- Phase 2: 2-3 hours (parallel: one on models, one on auth)
- Phases 3-5 Core: 4-5 hours (parallel: frontend dev on UI, backend dev on services; stagger tasks to avoid bottlenecks)
- Phases 6-8 Admin: 4-5 hours (parallel development)
- Phase 9: 1-2 hours (parallel)
- **Total Estimate**: 10-15 hours cumulative (1-2 working days with parallelization)

---

## MVP Scope Definition

**Minimum Viable Product = Phases 1-5**

- ✅ Core booking workflows (User Stories 1-3): Browse desks, create reservation, view/cancel
- ✅ Authentication & authorization (mock test users)
- ✅ Database with concurrency safety
- ✅ Full test coverage for booking logic
- ✅ Responsive UI for workers

**NOT in MVP (Deferred to Phase 2 release)**:
- Admin desk/floor management (Phase 6)
- Admin user management (Phase 7)
- Occupancy reporting (Phase 8)

---

## Quality Checklist

Before marking a task complete, verify:

- [ ] Code follows HotDesk Constitution principles (data integrity, simplicity, testing)
- [ ] All acceptance scenarios from spec.md pass
- [ ] Database constraints enforced (no double bookings, daily limits, etc.)
- [ ] API responses match contract (data-model.md + contracts.md)
- [ ] Error messages are user-friendly per spec FR-014
- [ ] Tests written for business logic (pytest for backend, React Testing Library for frontend)
- [ ] No console errors or warnings
- [ ] Responsive design verified (mobile 375px+, tablet 768px+, desktop 1024px+)
- [ ] Git commit made with clear message and Copilot co-author trailer

---

## Task Status Tracking

Use the checkboxes above to track progress. Update status as tasks are completed.

**Suggested workflow**:
1. Complete Phase 1-2 sequentially (blocking)
2. Complete Phase 3-5 in sequence with parallelization within each phase
3. Complete Phases 6-8 in parallel after Phase 2 (can merge into main when Phase 5 ready)
4. Complete Phase 9 after all user stories done
5. Run full validation suite (quickstart.md scenarios)
6. Deploy to main branch

---

## Next Steps

1. **Start Phase 1**: Set up project structure
2. **Read plan.md** for technical context before implementing
3. **Reference data-model.md** for schema details
4. **Reference contracts.md** for API specifications
5. **Use quickstart.md** to validate workflows after each phase
6. **Run tests frequently**: After each phase, run relevant test suite

---

**Tasks Generated**: 2026-10-24  
**Total Tasks**: 158 implementation + testing tasks  
**Estimated Effort**: 25-35 hours (solo) or 10-15 hours (team of 2-3)  
**MVP Ready**: After Phase 5 completion + Phase 9 polish
**Status**: ✅ Ready for Implementation
