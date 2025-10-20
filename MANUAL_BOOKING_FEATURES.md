# Manual Booking System - Feature Documentation

## Overview
The manual booking system allows administrators to create bookings on behalf of customers with comprehensive validation, automatic van selection, and real-time seat availability checking.

---

## ✅ Key Features Implemented

### 1. **Automatic Boarding Van Selection**
- **Functionality**: Automatically selects the current boarding van for the chosen route
- **Query Logic**:
  ```dart
  - WHERE currentRouteId = selectedRouteId
  - WHERE status = 'boarding'
  - WHERE isActive = true
  - ORDER BY queuePosition
  - LIMIT 1
  ```
- **Display**: Shows van plate number, driver name, and current occupancy
- **Warning**: Displays alert if no boarding van is available

### 2. **Comprehensive Validation Checks**

#### Pre-Booking Validations:
1. ✅ **Form Validation**: All required fields (Name, Email, Phone)
2. ✅ **Seat Selection**: At least one seat must be selected
3. ✅ **Route Selection**: Valid route must be chosen
4. ✅ **Van Availability**: Boarding van must exist for the route
5. ✅ **Van Capacity**: Selected seats cannot exceed available capacity
6. ✅ **Van Status**: Van must be in 'boarding' status
7. ✅ **Maximum Seats**: Cannot exceed 5 seats per booking

#### Real-Time Checks:
- Seats are validated against existing bookings in Firestore
- Van occupancy is checked before confirming booking
- Reserved seats are visually indicated and non-selectable

### 3. **Van Capacity Management**
- **Current Occupancy Tracking**: 
  - Displays: `Capacity: X/20 seats` (X = current occupancy)
  - Updates occupancy automatically after booking creation
  
- **Available Seats Calculation**:
  ```dart
  availableSeats = van.capacity - van.currentOccupancy
  ```
  
- **Validation**: Prevents overbooking by checking:
  ```dart
  selectedSeats.length <= availableSeats
  ```

### 4. **Seat Layout (Based on Van Design)**
```
╔════════════════════════════════╗
║  [Driver]  [DIB-Door]  [DIB]   ║
║                                ║
║  [L1A] [L1B]     [R1A] [R1B]   ║
║  [L2A] [L2B]     [R2A] [R2B]   ║
║  [L3A] [L3B]     [R3A] [R3B]   ║
║  [L4A] [L4B]     [R4A] [R4B]   ║
╚════════════════════════════════╝
```
- **Total Selectable Seats**: 16 seats (4 rows × 4 columns)
- **Non-selectable**: Driver seat, DIB door position
- **Aisle Gap**: Visual separation between left and right columns

### 5. **Pricing System**

#### Base Pricing:
```
Base Fare = Route Base Price × Number of Seats
```

#### Optional Discount (13.33%):
```
Discount Amount = Base Fare × 0.1333
```
- Controlled by checkbox: "Apply 13.33% Discount"
- Only applied when admin explicitly checks the option

#### Booking Fee:
```
Booking Fee = ₱15.00 (always applied)
```

#### Total Calculation:
```
Total Amount = Base Fare - Discount (if checked) + ₱15
```

### 6. **Auto Date & Time**
- **Current Date/Time**: Automatically set to `DateTime.now()`
- **Display Format**: "EEEE, MMM dd, yyyy - h:mm a"
  - Example: "Monday, Oct 20, 2025 - 2:30 PM"
- **Visual Indicator**: Blue info box with calendar icon and check mark
- **No Manual Input**: Prevents human error in date/time selection

---

## 🔒 Error Prevention Measures

### 1. **Double-Check Validations**
```dart
// Step 1: Form validation
if (!_formKey.currentState!.validate()) return;

// Step 2: Seat selection check
if (_selectedSeats.isEmpty) return;

// Step 3: Route validation
if (_selectedRoute == null) return;

// Step 4: Van availability check
if (_selectedVan == null) return;

// Step 5: Capacity validation
if (_selectedSeats.length > availableSeats) return;

// Step 6: Van status validation
if (_selectedVan!.status != 'boarding') return;
```

### 2. **Real-Time Seat Reservation**
```dart
// Query existing bookings for same route and date
QuerySnapshot bookingSnapshot = await FirebaseFirestore.instance
    .collection('bookings')
    .where('routeId', isEqualTo: _selectedRouteId)
    .where('departureTime', isGreaterThanOrEqualTo: startOfDay)
    .where('departureTime', isLessThan: endOfDay)
    .where('bookingStatus', whereIn: ['confirmed', 'active'])
    .get();
```

### 3. **Occupancy Update After Booking**
```dart
// Automatically update van occupancy
final int newOccupancy = currentOccupancy + selectedSeats.length;
await FirebaseFirestore.instance
    .collection('vans')
    .doc(vanId)
    .update({'currentOccupancy': newOccupancy});
```

### 4. **User Feedback**
- ✅ Success messages with detailed information
- ⚠️ Warning messages for non-critical issues
- ❌ Error messages with clear explanations
- 🎯 Real-time visual indicators (colors, icons)

---

## 📊 Booking Flow

### Step 1: Route Selection
1. Admin selects a route from dropdown
2. System queries for boarding van on that route
3. Van information displayed (if available)
4. Warning shown if no boarding van found
5. Reserved seats loaded from Firestore

### Step 2: Passenger Information
1. Admin enters: Name, Email, Phone
2. Payment method: GCash (default), PayMaya, Cash
3. Form validation on all fields

### Step 3: Seat Selection
1. Visual seat grid displayed
2. Reserved seats shown in red (non-selectable)
3. Available seats shown in grey (clickable)
4. Selected seats shown in blue
5. Maximum 5 seats enforced with warning
6. Price breakdown updated in real-time
7. Optional discount checkbox available

### Step 4: Submission
1. All validations executed
2. Van capacity checked
3. Booking created in Firestore
4. Van occupancy updated
5. Success confirmation displayed

---

## 🎨 Visual Indicators

### Seat Colors:
- **Grey**: Available seat
- **Blue**: Selected seat
- **Red**: Reserved/Booked seat
- **Green**: Discount indicator (when checked)

### Status Messages:
- **Green with ✅**: Success (booking created)
- **Orange with ⚠️**: Warning (no van available)
- **Red with ❌**: Error (validation failed)
- **Blue with 🎯**: Information (auto-set values)

### Van Information Display:
```
┌─────────────────────────────────────┐
│ 🚐 Boarding Van                     │
│ ABC-123 - Driver: John Doe         │
│ Capacity: 5/20 seats                │
│                              ✓      │
└─────────────────────────────────────┘
```

---

## 🔧 Technical Implementation

### Database Queries:
1. **Get Boarding Van**: 
   - Collection: `vans`
   - Filters: `currentRouteId`, `status='boarding'`, `isActive=true`
   
2. **Get Reserved Seats**: 
   - Collection: `bookings`
   - Filters: `routeId`, `departureTime (same day)`, `bookingStatus (active/confirmed)`

3. **Create Booking**: 
   - Collection: `bookings`
   - Auto-generate document ID
   
4. **Update Van Occupancy**: 
   - Collection: `vans`
   - Update: `currentOccupancy` field

### Error Handling:
```dart
try {
  // Booking creation logic
  await createBooking();
  await updateVanOccupancy();
  showSuccessMessage();
} catch (e) {
  print('❌ Error: $e');
  showErrorMessage(e);
} finally {
  setState(() => _isLoading = false);
}
```

---

## 📝 Data Models

### Booking Model:
```dart
Booking(
  id: String,
  userId: 'admin_manual_booking',
  userName: String,
  userEmail: String,
  routeId: String,
  routeName: String,
  origin: String,
  destination: String,
  departureTime: DateTime,
  bookingDate: DateTime,
  seatIds: List<String>,
  numberOfSeats: int,
  basePrice: double,
  discountAmount: double,
  totalAmount: double,
  paymentMethod: String,
  paymentStatus: 'paid',
  bookingStatus: 'confirmed',
  eTicketId: String,
  passengerDetails: PassengerDetails,
  discountApplied: String?,
)
```

### Van Model:
```dart
Van(
  id: String,
  plateNumber: String,
  capacity: int,
  currentOccupancy: int,
  driver: Driver,
  status: String, // 'boarding', 'in_queue', 'in_transit', etc.
  currentRouteId: String?,
  queuePosition: int,
  isActive: bool,
)
```

---

## 🚀 Future Enhancements (Potential)

1. **Booking Confirmation Email**: Auto-send e-ticket to passenger
2. **QR Code Generation**: Generate QR code for booking verification
3. **Multi-Van Support**: Allow admin to choose from multiple boarding vans
4. **Seat Hold Timer**: Reserve seats for X minutes during booking process
5. **Payment Integration**: Process real payments via GCash/PayMaya API
6. **Booking History**: Track admin who created manual bookings
7. **Bulk Booking**: Create multiple bookings at once
8. **Seat Preference**: Allow selection of window/aisle preferences

---

## 📞 Support & Maintenance

### Common Issues:
1. **No Boarding Van**: Ensure at least one van is set to 'boarding' status for the route
2. **Seats Already Reserved**: Check if bookings exist for the same route/time
3. **Capacity Exceeded**: Verify van's `currentOccupancy` is accurate
4. **Status Validation Failed**: Confirm van status is exactly 'boarding' (case-sensitive)

### Database Maintenance:
- Regularly clean up old bookings
- Reset `currentOccupancy` to 0 when vans complete trips
- Monitor van status transitions for consistency

---

**Last Updated**: October 20, 2025  
**Version**: 1.0  
**Status**: Production Ready ✅
