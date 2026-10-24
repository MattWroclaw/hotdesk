# Quickstart: Desk Reservation System — Validation Guide

**Feature**: Desk Reservation System  
**Date**: 2026-10-24  
**Purpose**: End-to-end validation scenarios proving core booking workflows function correctly

---

## Prerequisites

1. **Backend Running**:
   ```powershell
   cd backend
   python -m venv venv
   .\venv\Scripts\activate
   pip install -r requirements.txt
   python -m uvicorn app.main:app --reload --port 8000
   ```
   Expected: "Uvicorn running on http://127.0.0.1:8000"

2. **Frontend Running** (optional for E2E):
   ```powershell
   cd frontend
   npm install
   npm run dev
   ```
   Expected: "Local: http://localhost:3000"

3. **Test Users Available** (created automatically on first backend startup):
   - `alice@company.com` / `dev-password` (worker)
   - `bob@company.com` / `dev-password` (worker)
   - `admin@company.com` / `admin-password` (admin)

---

## Test Scenario 1: Browse Available Desks (P1)

**Objective**: Verify workers can view available desks grouped by floor for a selected date.

**Setup**: Backend running; test users seeded.

### Scenario 1A: View Available Desks for Today

**Command** (PowerShell):
```powershell
# 1. Get today's date in ISO format
$today = Get-Date -Format "yyyy-MM-dd"
Write-Output "Testing availability for: $today"

# 2. Login as alice (worker)
$loginResponse = Invoke-WebRequest -Uri "http://localhost:8000/api/auth/login" `
  -Method POST `
  -Body '{"email":"alice@company.com","password":"dev-password"}' `
  -ContentType "application/json"

$token = ($loginResponse.Content | ConvertFrom-Json).data.token
Write-Output "Login token: $($token.Substring(0, 20))..."

# 3. Fetch desks for today, grouped by floor
$desksResponse = Invoke-WebRequest -Uri "http://localhost:8000/api/desks?date=$today" `
  -Headers @{"Authorization"="Bearer $token"} `
  -Method GET

$desks = $desksResponse.Content | ConvertFrom-Json
Write-Output "Desks available today:"
$desks.data | ForEach-Object {
  Write-Output "  Floor: $($_.floor_name)"
  $_.desks | ForEach-Object {
    Write-Output "    Desk $($_.desk_number): $($_.status) $(if($_.booked_by) { "by $($_.booked_by_name)" } else { "" })"
  }
}
```

**Expected Output**:
```
Desks available today:
  Floor: Floor 1 - Finance
    Desk 1: available
    Desk 2: available
    Desk 3: reserved by Bob Jones
  Floor: Floor 2 - Marketing
    Desk 1: available
    Desk 2: available
```

**Acceptance Criteria**:
- ✅ Response status: 200 OK
- ✅ Desks grouped by floor
- ✅ Each desk shows status (available/reserved)
- ✅ Booked desks show who booked them
- ✅ Inactive desks not shown
- ✅ No implementation details leak into response

---

### Scenario 1B: View Desks for Future Date

**Command** (PowerShell):
```powershell
# Test availability for tomorrow
$tomorrow = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")
Write-Output "Testing availability for: $tomorrow"

$desksResponse = Invoke-WebRequest -Uri "http://localhost:8000/api/desks?date=$tomorrow" `
  -Headers @{"Authorization"="Bearer $token"} `
  -Method GET

$desks = $desksResponse.Content | ConvertFrom-Json
Write-Output "Tomorrow's availability retrieved: $($desks.data.Count) floors shown"
```

**Expected Output**:
```
Tomorrow's availability retrieved: 2 floors shown
```

**Acceptance Criteria**:
- ✅ Response status: 200 OK
- ✅ Future date queries work
- ✅ Desks reset to all available (clean slate)

---

## Test Scenario 2: Create a Desk Reservation (P1)

**Objective**: Verify workers can book available desks and system prevents conflicts.

### Scenario 2A: Successful Booking

**Command** (PowerShell):
```powershell
$tomorrow = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")

# Book desk 1 on floor 1 for tomorrow
$bookingPayload = @{
    desk_id = 1
    reservation_date = $tomorrow
} | ConvertTo-Json

$bookResponse = Invoke-WebRequest -Uri "http://localhost:8000/api/reservations" `
  -Method POST `
  -Body $bookingPayload `
  -ContentType "application/json" `
  -Headers @{"Authorization"="Bearer $token"}

$reservation = ($bookResponse.Content | ConvertFrom-Json).data
Write-Output "Reservation created:"
Write-Output "  ID: $($reservation.id)"
Write-Output "  Desk: Floor $($reservation.floor_name), Desk $($reservation.desk_number)"
Write-Output "  Date: $($reservation.reservation_date)"
Write-Output "  Status: $($reservation.status)"
Write-Output "  Cancelable: $($reservation.is_cancelable)"
```

**Expected Output**:
```
Reservation created:
  ID: 1
  Desk: Floor 1 - Finance, Desk 1
  Date: 2026-10-25
  Status: active
  Cancelable: True
```

**Acceptance Criteria**:
- ✅ Response status: 201 Created
- ✅ Reservation ID returned
- ✅ Desk marked as active/upcoming
- ✅ is_cancelable = true (future date)
- ✅ Desk now shows as "reserved" when viewed by other workers

---

### Scenario 2B: Double-Booking Prevention

**Command** (PowerShell):
```powershell
# Try to book the same desk for same date (already booked by alice)
$conflictPayload = @{
    desk_id = 1
    reservation_date = $tomorrow
} | ConvertTo-Json

try {
  $conflictResponse = Invoke-WebRequest -Uri "http://localhost:8000/api/reservations" `
    -Method POST `
    -Body $conflictPayload `
    -ContentType "application/json" `
    -Headers @{"Authorization"="Bearer $token"} `
    -ErrorAction Stop
} catch {
  $error = $_.Exception.Response
  Write-Output "Expected conflict detected:"
  Write-Output "  Status: $($error.StatusCode)"
  $content = $error.Content.ReadAsStream() | ForEach-Object { [System.IO.StreamReader]::new($_).ReadToEnd() }
  $errorData = $content | ConvertFrom-Json
  Write-Output "  Message: $($errorData.message)"
}
```

**Expected Output**:
```
Expected conflict detected:
  Status: 409
  Message: This desk was booked while you were viewing. Please select another desk.
```

**Acceptance Criteria**:
- ✅ Response status: 409 Conflict
- ✅ Clear error message about desk already booked
- ✅ No reservation created
- ✅ Desk remains booked by alice

---

### Scenario 2C: Daily Limit Per Worker

**Command** (PowerShell):
```powershell
# Login as bob (second worker)
$bobLogin = Invoke-WebRequest -Uri "http://localhost:8000/api/auth/login" `
  -Method POST `
  -Body '{"email":"bob@company.com","password":"dev-password"}' `
  -ContentType "application/json"
$bobToken = ($bobLogin.Content | ConvertFrom-Json).data.token

# Bob books desk 2 for same day (should succeed)
$booking2Payload = @{
    desk_id = 2
    reservation_date = $tomorrow
} | ConvertTo-Json

$bob1Response = Invoke-WebRequest -Uri "http://localhost:8000/api/reservations" `
  -Method POST `
  -Body $booking2Payload `
  -ContentType "application/json" `
  -Headers @{"Authorization"="Bearer $bobToken"}

Write-Output "Bob's first booking: Success (Desk 2)"

# Bob tries to book a third desk for same day (should fail - already has one reservation)
$booking3Payload = @{
    desk_id = 5
    reservation_date = $tomorrow
} | ConvertTo-Json

try {
  $bob2Response = Invoke-WebRequest -Uri "http://localhost:8000/api/reservations" `
    -Method POST `
    -Body $booking3Payload `
    -ContentType "application/json" `
    -Headers @{"Authorization"="Bearer $bobToken"} `
    -ErrorAction Stop
} catch {
  $error = $_.Exception.Response
  Write-Output "Bob's second booking for same day: Correctly Rejected"
  Write-Output "  Status: $($error.StatusCode)"
  $content = $error.Content.ReadAsStream() | ForEach-Object { [System.IO.StreamReader]::new($_).ReadToEnd() }
  $errorData = $content | ConvertFrom-Json
  Write-Output "  Message: $($errorData.message)"
}
```

**Expected Output**:
```
Bob's first booking: Success (Desk 2)
Bob's second booking for same day: Correctly Rejected
  Status: 400
  Message: You already have a desk reserved for this date
```

**Acceptance Criteria**:
- ✅ Worker can book 1 desk per day
- ✅ System rejects 2nd booking same day with 400 status
- ✅ Clear error message about daily limit
- ✅ First booking remains valid

---

## Test Scenario 3: View and Cancel Personal Reservations (P1)

**Objective**: Verify workers can view upcoming/past reservations and cancel only upcoming ones.

### Scenario 3A: View Personal Reservations

**Command** (PowerShell):
```powershell
# Alice views her reservations
$reservationsResponse = Invoke-WebRequest -Uri "http://localhost:8000/api/reservations" `
  -Method GET `
  -Headers @{"Authorization"="Bearer $token"}

$reservations = ($reservationsResponse.Content | ConvertFrom-Json).data
Write-Output "Alice's Upcoming Reservations:"
$reservations.upcoming | ForEach-Object {
  Write-Output "  Desk $($_.desk_number) on $($_.reservation_date) - $($_.display_status)"
}

Write-Output "Alice's Past Reservations:"
if ($reservations.past.Count -eq 0) {
  Write-Output "  (none yet)"
} else {
  $reservations.past | ForEach-Object {
    Write-Output "  Desk $($_.desk_number) on $($_.reservation_date) - $($_.display_status)"
  }
}
```

**Expected Output**:
```
Alice's Upcoming Reservations:
  Desk 1 on 2026-10-25 - Active
Alice's Past Reservations:
  (none yet)
```

**Acceptance Criteria**:
- ✅ Response status: 200 OK
- ✅ Upcoming and past separated
- ✅ Correct display_status (Active, Completed, Canceled)
- ✅ Only user's own reservations returned

---

### Scenario 3B: Cancel Upcoming Reservation

**Command** (PowerShell):
```powershell
# Alice cancels her reservation
$reservationId = $reservations.upcoming[0].id
Write-Output "Canceling reservation ID: $reservationId"

$cancelResponse = Invoke-WebRequest -Uri "http://localhost:8000/api/reservations/$reservationId" `
  -Method DELETE `
  -Headers @{"Authorization"="Bearer $token"}

$result = ($cancelResponse.Content | ConvertFrom-Json).data
Write-Output "Cancellation result:"
Write-Output "  Reservation ID: $($result.id)"
Write-Output "  New Status: $($result.status)"
Write-Output "  Canceled At: $($result.canceled_at)"

# Verify desk is now available again
$desksResponse = Invoke-WebRequest -Uri "http://localhost:8000/api/desks?date=$tomorrow" `
  -Headers @{"Authorization"="Bearer $token"} `
  -Method GET

$desks = ($desksResponse.Content | ConvertFrom-Json).data
$desk1 = $desks[0].desks | Where-Object { $_.desk_number -eq "1" }
Write-Output "Desk 1 status after cancellation: $($desk1.status)"
```

**Expected Output**:
```
Canceling reservation ID: 1
Cancellation result:
  Reservation ID: 1
  New Status: canceled
  Canceled At: 2026-10-24T15:45:00Z
Desk 1 status after cancellation: available
```

**Acceptance Criteria**:
- ✅ Response status: 200 OK
- ✅ Reservation status changed to "canceled"
- ✅ canceled_at timestamp set
- ✅ Desk immediately shows as available again for other workers
- ✅ Cancellation history preserved (not hard-deleted)

---

### Scenario 3C: Cannot Cancel Past Reservation

**Command** (PowerShell):
```powershell
# Create and immediately try to cancel a past-dated reservation (manual DB manipulation for test)
# For this scenario, assume a past reservation exists (would need DB setup)

# Try to cancel a past reservation
$pastReservationId = 999  # Example ID of past reservation

try {
  $pastCancelResponse = Invoke-WebRequest -Uri "http://localhost:8000/api/reservations/$pastReservationId" `
    -Method DELETE `
    -Headers @{"Authorization"="Bearer $token"} `
    -ErrorAction Stop
} catch {
  $error = $_.Exception.Response
  Write-Output "Attempt to cancel past reservation: Correctly Rejected"
  Write-Output "  Status: $($error.StatusCode)"
  $content = $error.Content.ReadAsStream() | ForEach-Object { [System.IO.StreamReader]::new($_).ReadToEnd() }
  $errorData = $content | ConvertFrom-Json
  Write-Output "  Message: $($errorData.message)"
}
```

**Expected Output**:
```
Attempt to cancel past reservation: Correctly Rejected
  Status: 400
  Message: Only upcoming reservations can be canceled
```

**Acceptance Criteria**:
- ✅ Response status: 400 Bad Request
- ✅ Clear message about past reservations being non-cancelable
- ✅ Reservation unchanged

---

## Test Scenario 4: Admin Manage Desks & Floors (P2)

**Objective**: Verify admins can add/edit/deactivate desks and floors.

### Scenario 4A: Admin Creates New Floor

**Command** (PowerShell):
```powershell
# Login as admin
$adminLogin = Invoke-WebRequest -Uri "http://localhost:8000/api/auth/login" `
  -Method POST `
  -Body '{"email":"admin@company.com","password":"admin-password"}' `
  -ContentType "application/json"
$adminToken = ($adminLogin.Content | ConvertFrom-Json).data.token

# Create new floor
$floorPayload = @{
    floor_name = "Floor 3 - Engineering"
    floor_number = 3
} | ConvertTo-Json

$floorResponse = Invoke-WebRequest -Uri "http://localhost:8000/api/admin/floors" `
  -Method POST `
  -Body $floorPayload `
  -ContentType "application/json" `
  -Headers @{"Authorization"="Bearer $adminToken"}

$floor = ($floorResponse.Content | ConvertFrom-Json).data
Write-Output "Floor created:"
Write-Output "  ID: $($floor.id)"
Write-Output "  Name: $($floor.floor_name)"
Write-Output "  Number: $($floor.floor_number)"
```

**Expected Output**:
```
Floor created:
  ID: 3
  Name: Floor 3 - Engineering
  Number: 3
```

**Acceptance Criteria**:
- ✅ Response status: 201 Created
- ✅ Floor ID returned
- ✅ New floor appears in desk availability view

---

### Scenario 4B: Admin Adds Desks to Floor

**Command** (PowerShell):
```powershell
# Add desks to newly created floor
$deskPayload = @{
    desk_number = "1"
    floor_id = 3
} | ConvertTo-Json

$deskResponse = Invoke-WebRequest -Uri "http://localhost:8000/api/admin/desks" `
  -Method POST `
  -Body $deskPayload `
  -ContentType "application/json" `
  -Headers @{"Authorization"="Bearer $adminToken"}

$desk = ($deskResponse.Content | ConvertFrom-Json).data
Write-Output "Desk created on Floor 3:"
Write-Output "  ID: $($desk.id)"
Write-Output "  Desk Number: $($desk.desk_number)"
Write-Output "  Floor ID: $($desk.floor_id)"

# Verify desk appears in availability view
$today = Get-Date -Format "yyyy-MM-dd"
$desksResponse = Invoke-WebRequest -Uri "http://localhost:8000/api/desks?date=$today" `
  -Headers @{"Authorization"="Bearer $token"} `
  -Method GET

$allDesks = ($desksResponse.Content | ConvertFrom-Json).data
$floor3Desks = $allDesks | Where-Object { $_.floor_id -eq 3 }
Write-Output "Floor 3 now visible with $($floor3Desks.desks.Count) desk(s)"
```

**Expected Output**:
```
Desk created on Floor 3:
  ID: 6
  Desk Number: 1
  Floor ID: 3
Floor 3 now visible with 1 desk(s)
```

**Acceptance Criteria**:
- ✅ Response status: 201 Created
- ✅ Desk added to correct floor
- ✅ New desk immediately available for booking

---

## Test Scenario 5: Admin Occupancy View (P3)

**Objective**: Verify admins can view office occupancy for any date.

**Command** (PowerShell):
```powershell
$tomorrow = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")

# Admin views occupancy for tomorrow (when alice had a booking, now canceled)
$occupancyResponse = Invoke-WebRequest -Uri "http://localhost:8000/api/admin/occupancy?date=$tomorrow" `
  -Method GET `
  -Headers @{"Authorization"="Bearer $adminToken"}

$occupancy = ($occupancyResponse.Content | ConvertFrom-Json).data
Write-Output "Occupancy for $tomorrow:"
Write-Output "  Total Desks: $($occupancy.occupancy_summary.total_desks)"
Write-Output "  Booked Desks: $($occupancy.occupancy_summary.booked_desks)"
Write-Output "  Available Desks: $($occupancy.occupancy_summary.available_desks)"
Write-Output "  Occupancy Rate: $($occupancy.occupancy_summary.occupancy_rate)%"

Write-Output "`nDetailed Breakdown:"
$occupancy.floors | ForEach-Object {
  Write-Output "  Floor: $($_.floor_name)"
  $_.desks | ForEach-Object {
    Write-Output "    Desk $($_.desk_number): $($_.status) $(if($_.booked_by_email) { "by $($_.booked_by_name)" } else { "" })"
  }
}
```

**Expected Output**:
```
Occupancy for 2026-10-25:
  Total Desks: 7
  Booked Desks: 1
  Available Desks: 6
  Occupancy Rate: 14.3%

Detailed Breakdown:
  Floor: Floor 1 - Finance
    Desk 1: available
    Desk 2: reserved by Bob Jones
    Desk 3: available
  Floor: Floor 2 - Marketing
    Desk 1: available
    Desk 2: available
  Floor: Floor 3 - Engineering
    Desk 1: available
```

**Acceptance Criteria**:
- ✅ Response status: 200 OK
- ✅ Occupancy metrics calculated correctly
- ✅ Desks grouped by floor
- ✅ Admin-only view (non-admins receive 403)

---

## Concurrent Booking Test (P1 - Advanced)

**Objective**: Verify system prevents double-booking under concurrent load.

**Command** (PowerShell - run multiple terminals simultaneously):

Terminal 1:
```powershell
# Alice attempts to book desk 1 for specific date
$bookingPayload = @{
    desk_id = 1
    reservation_date = "2026-10-26"
} | ConvertTo-Json

Invoke-WebRequest -Uri "http://localhost:8000/api/reservations" `
  -Method POST `
  -Body $bookingPayload `
  -ContentType "application/json" `
  -Headers @{"Authorization"="Bearer $token"} | Write-Output "Terminal 1: $($_.StatusCode)"
```

Terminal 2 (start at same time):
```powershell
# Bob also attempts to book same desk for same date
$bookingPayload = @{
    desk_id = 1
    reservation_date = "2026-10-26"
} | ConvertTo-Json

Invoke-WebRequest -Uri "http://localhost:8000/api/reservations" `
  -Method POST `
  -Body $bookingPayload `
  -ContentType "application/json" `
  -Headers @{"Authorization"="Bearer $bobToken"} | Write-Output "Terminal 2: $($_.StatusCode)"
```

**Expected Result**:
- Terminal 1: 201 Created (Alice wins)
- Terminal 2: 409 Conflict (Bob gets conflict message)

**Acceptance Criteria**:
- ✅ Exactly one booking succeeds
- ✅ Other booking fails with clear 409 error
- ✅ No data corruption or inconsistency

---

## Summary: Validation Checklist

| Scenario | Objective | Status |
|----------|-----------|--------|
| 1A | View desks for today | ✅ |
| 1B | View desks for future date | ✅ |
| 2A | Successful booking | ✅ |
| 2B | Double-booking prevention | ✅ |
| 2C | Daily limit per worker | ✅ |
| 3A | View personal reservations | ✅ |
| 3B | Cancel upcoming reservation | ✅ |
| 3C | Cannot cancel past reservation | ✅ |
| 4A | Admin creates floor | ✅ |
| 4B | Admin adds desks | ✅ |
| 5 | Admin occupancy view | ✅ |
| Concurrent | Double-booking under load | ✅ |

**All scenarios passing?** ✅ Feature ready for production planning.

---

**Quickstart Guide Status**: ✅ Complete and testable

**Next Phase**: `/speckit-tasks` to generate implementation tasks with dependencies
