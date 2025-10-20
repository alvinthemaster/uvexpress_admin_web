# Van Selection - Comprehensive Validation & Error Handling

## 🔍 Overview
The van selection system has been enhanced with multi-layer validation, comprehensive error handling, and detailed logging to ensure only valid boarding vans can be selected for manual bookings.

---

## ✅ Validation Layers

### Layer 1: Database Query Filtering
```dart
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
    .collection('vans')
    .where('status', isEqualTo: 'boarding')  // Only boarding vans
    .where('isActive', isEqualTo: true)      // Only active vans
    .orderBy('queuePosition')                 // Ordered by queue
    .snapshots()
)
```

**Filtered Out:**
- ❌ Vans with status != 'boarding' (in_queue, in_transit, maintenance, etc.)
- ❌ Inactive vans (isActive = false)
- ❌ Deleted/archived vans

**Result:** Only actively boarding vans appear in the list

---

### Layer 2: Selection-Time Validation
When a user taps on a van card, the following checks are performed:

#### ✅ Check 1: Status Validation
```dart
if (!isValidBoardingStatus) {
  // Show error: "Cannot select van ABC-123. Status must be 'boarding'"
  return;
}
```
- Validates status is exactly "boarding" (case-insensitive)
- Prevents selection if status changed after loading

#### ✅ Check 2: Capacity Validation
```dart
if (!hasAvailableSeats) {
  // Show error: "Van ABC-123 is full. No seats available."
  return;
}
```
- Calculates: `availableSeats = capacity - currentOccupancy`
- Prevents selection if van is at full capacity
- Visual indicator: "VAN FULL" banner shown on card

#### ✅ Check 3: Route Assignment Validation
```dart
if (van.currentRouteId == null || van.currentRouteId!.isEmpty) {
  // Show error: "Van ABC-123 has no route assigned."
  return;
}
```
- Ensures van has a valid route ID
- Prevents booking without destination information

---

### Layer 3: Route Loading Validation
After van selection, route information is loaded:

```dart
try {
  final routeDoc = await FirebaseFirestore.instance
    .collection('routes')
    .doc(van.currentRouteId)
    .get();
  
  if (routeDoc.exists) {
    // ✅ Route loaded successfully
  } else {
    // ⚠️ Warning: Route document not found
  }
} catch (e) {
  // ❌ Error loading route
}
```

---

## 🎨 Visual Indicators

### 1. **Loading State**
```
┌──────────────────────────┐
│      🔄 Loading...       │
└──────────────────────────┘
```
- Shows CircularProgressIndicator while fetching data
- Centered with padding for better UX

### 2. **Error State**
```
┌────────────────────────────────────┐
│ ❌ Error loading vans              │
│ Error message details here...      │
└────────────────────────────────────┘
```
- Red background with error icon
- Displays specific error message
- Helps debugging connection/permission issues

### 3. **Empty State**
```
┌────────────────────────────────────┐
│ ⚠️ No boarding vans available      │
│ Please check van management.       │
└────────────────────────────────────┘
```
- Orange warning background
- Clear action guidance for admins

### 4. **Summary Info Box**
```
┌────────────────────────────────────┐
│ ℹ️ 3 boarding van(s) found (1 full)│
└────────────────────────────────────┘
```
- Blue info box at top of van list
- Shows total count and how many are full
- Quick overview before scrolling

### 5. **Full Van Card**
```
┌────────────────────────────────────┐
│ ⛔ VAN FULL - No seats available   │
│ ───────────────────────────────────│
│ 🚐 ABC-123      [BOARDING]         │
│    Driver: John Doe                │
│                                     │
│ 📍 Manila → Baguio   ₱450.00       │
│ 💺 Capacity: 20/20                 │
│ [████████████████████] 0 seats left│
│ #️⃣ Queue Position: #1              │
└────────────────────────────────────┘
```
- Grayed out appearance
- Red "VAN FULL" banner at top
- Not selectable (validation prevents tap)

### 6. **Available Van Card**
```
┌────────────────────────────────────┐
│ 🚐 ABC-123      [BOARDING]     ✓   │
│    Driver: John Doe                │
│                                     │
│ 📍 Manila → Baguio   ₱450.00       │
│ 💺 Capacity: 5/20                  │
│ [████░░░░░░░░░░░░] 15 seats left   │
│ #️⃣ Queue Position: #1              │
└────────────────────────────────────┘
```
- White/blue background when selected
- Green progress bar if <50% full
- Orange bar if 50-80% full
- Red bar if >80% full
- Checkmark icon when selected

---

## 📝 Debug Logging

### Console Output Examples:

#### Successful Van Load:
```
✅ Loaded 3 boarding van(s)
```

#### Van Selection:
```
🚐 Selected van: ABC-123 (Status: boarding, Available: 15 seats)
```

#### Route Load Success:
```
✅ Route loaded: Route A (Manila → Baguio)
```

#### No Vans Available:
```
⚠️ No boarding vans found in database
```

#### Error Loading Vans:
```
❌ Error loading vans: [error details]
```

#### Route Not Found:
```
⚠️ Route document not found for ID: route123
```

#### Route Load Error:
```
❌ Error loading route: [error details]
```

---

## 🚫 Validation Error Messages

### User-Facing SnackBar Messages:

1. **Invalid Status**
   ```
   ❌ Cannot select van ABC-123. Status must be "boarding" (current: in_queue)
   ```

2. **No Available Seats**
   ```
   ❌ Van ABC-123 is full. No seats available.
   ```

3. **No Route Assigned**
   ```
   ❌ Van ABC-123 has no route assigned.
   ```

4. **Route Not Found**
   ```
   ⚠️ Warning: Route information not found
   ```

5. **Route Load Error**
   ```
   ❌ Error loading route: [error message]
   ```

---

## 🔄 Real-Time Updates

### Stream-Based Architecture:
```dart
.snapshots()  // Real-time listener
```

**Benefits:**
- ✅ Instant updates when van status changes
- ✅ Live capacity updates as bookings are made
- ✅ Automatic list refresh without manual reload
- ✅ New boarding vans appear immediately
- ✅ Full vans show warning immediately

**Example Scenarios:**
1. Van changes from "in_queue" to "boarding" → Appears in list instantly
2. Van reaches full capacity → Shows "VAN FULL" banner
3. Van status changes to "in_transit" → Disappears from list
4. New van assigned to route and set to boarding → Appears in list

---

## 🛡️ Error Prevention Strategies

### 1. **Multiple Validation Points**
- Pre-selection (query filters)
- During selection (tap validation)
- Post-selection (route loading)
- Pre-booking (final validation in _submitBooking)

### 2. **Defensive Null Checks**
```dart
if (van.currentRouteId != null && van.currentRouteId!.isNotEmpty) {
  // Proceed with route loading
}
```

### 3. **Try-Catch Blocks**
```dart
try {
  // Database operations
} catch (e) {
  print('❌ Error: $e');
  // Show user-friendly error message
}
```

### 4. **Mounted Widget Checks**
```dart
if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(...)
}
```
- Prevents errors after widget disposal
- Safe async operation handling

---

## 📊 Data Flow

```
1. StreamBuilder queries Firestore
   ↓
2. Filter: status='boarding' AND isActive=true
   ↓
3. Map documents to Van objects
   ↓
4. Calculate availableSeats for each
   ↓
5. Display van cards with visual indicators
   ↓
6. User taps van card
   ↓
7. Validate: status + capacity + route assignment
   ↓
8. Load route information from Firestore
   ↓
9. Validate route exists
   ↓
10. Update state: _selectedVan + _selectedRoute
   ↓
11. Enable "Continue" button
   ↓
12. Final validation in _submitBooking()
```

---

## 🧪 Test Scenarios

### ✅ Success Cases:
1. **Normal Selection**: Select van with available seats → Success
2. **Route Load**: Van has valid route → Route loads correctly
3. **Real-time Update**: Van capacity updates → UI reflects change
4. **Multiple Vans**: Several boarding vans → All displayed correctly

### ⚠️ Edge Cases Handled:
1. **No Boarding Vans**: Database empty → Warning message shown
2. **All Vans Full**: No available seats → Full banners displayed
3. **Invalid Route ID**: Route document missing → Warning shown
4. **Network Error**: Firestore timeout → Error state displayed
5. **Status Change During Selection**: Status changes → Selection blocked

### 🐛 Error Cases Prevented:
1. **Selecting Full Van**: Validation blocks → Error message
2. **Selecting Non-Boarding Van**: Query filters out → Never appears
3. **Selecting Inactive Van**: Query filters out → Never appears
4. **Missing Route**: Validation blocks → Error message
5. **Concurrent Booking**: Real-time stream → Capacity updates

---

## 📈 Performance Considerations

### Optimizations:
- **Indexed Queries**: Firestore compound index on `status + isActive + queuePosition`
- **Efficient Mapping**: Single pass through documents
- **Lazy Loading**: Routes loaded only when van selected
- **Stream Caching**: Firebase SDK caches data locally

### Monitoring Points:
- Query execution time (should be <500ms)
- Number of vans returned (typically 1-5)
- Route loading time (should be <200ms)
- Stream updates frequency (varies with activity)

---

## 🔐 Security Considerations

### Firestore Rules Should Include:
```javascript
match /vans/{vanId} {
  allow read: if request.auth != null && 
                 request.auth.token.role == 'admin';
}

match /routes/{routeId} {
  allow read: if request.auth != null;
}
```

### Data Validation:
- Van status enum validation
- Capacity range checks (0 ≤ occupancy ≤ capacity)
- Route ID format validation
- Queue position non-negative

---

## 📱 User Experience

### Smooth Flow:
1. See boarding vans instantly (real-time)
2. Visual capacity indicators (progress bars)
3. Clear selection feedback (blue highlight, checkmark)
4. Immediate error messages (helpful, not technical)
5. Automatic route loading (no extra steps)

### Accessibility:
- Clear error messages
- Color + icon indicators (not color-alone)
- Sufficient contrast ratios
- Touch targets ≥ 48x48dp

---

## 🚀 Future Enhancements (Suggestions)

1. **Search/Filter**: Filter vans by route or driver
2. **Sort Options**: By capacity, queue position, route
3. **Van Details Modal**: Tap for maintenance history, ratings
4. **Favorites**: Star frequently used vans
5. **Capacity Alerts**: Notify when van approaches full
6. **Historical Data**: Show average booking times
7. **Driver Contact**: Quick call/message driver

---

**Last Updated**: October 20, 2025  
**Status**: Production Ready with Comprehensive Validation ✅  
**Test Coverage**: All critical paths validated
