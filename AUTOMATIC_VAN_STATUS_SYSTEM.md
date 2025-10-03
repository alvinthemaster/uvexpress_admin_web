# Automatic Van Status Management System

## Overview
The van management system now automatically updates van statuses to "Full" when all seats are reserved, ensuring full vans are not selectable in the passenger app.

## Key Features

### 1. Automatic Status Updates
- **Full Status**: Vans are automatically marked as "full" when `currentOccupancy >= capacity`
- **Status Restoration**: When occupancy drops below capacity, vans return to appropriate bookable status:
  - `boarding` if assigned to a route
  - `in_queue` if not assigned to a route

### 2. Booking Integration
- **Occupancy Tracking**: Real-time occupancy updates based on confirmed bookings
- **Status Synchronization**: Van status automatically updates after every booking change
- **Passenger App Filtering**: Full vans are excluded from available van lists

### 3. Admin Controls
- **Manual Updates**: Admin can manually adjust occupancy in van management screen
- **Bulk Status Update**: "Update All Statuses" button refreshes all van statuses
- **Visual Indicators**: Progress bars show occupancy levels with color coding

## Implementation Details

### Van Model (`van_model.dart`)
```dart
bool get canBook {
  final normalizedStatus = status.toLowerCase().trim();
  return isActive &&
      VanStatus.bookableStatuses.contains(normalizedStatus) &&
      currentOccupancy < capacity; // Prevents booking when full
}
```

### Van Service (`van_service.dart`)
Key methods:
- `updateVanOccupancy()` - Updates occupancy and checks status
- `_checkAndUpdateVanStatus()` - Automatically updates status based on occupancy
- `getAvailableVansForBooking()` - Returns only bookable vans
- `checkAndUpdateVanStatusAfterBooking()` - Public method for external calls

### Booking Service (`booking_service.dart`)
Key methods:
- `createBooking()` - Creates booking and updates van occupancy
- `updateBookingStatusWithVanUpdate()` - Updates booking status and van occupancy
- `_updateVanOccupancyForRoute()` - Updates all vans on a route

### Status Constants (`van_status_constants.dart`)
- Added `full` status with proper display mapping
- `full` status excluded from `bookableStatuses` list
- Color coding: Full status shows red color

## Usage Examples

### 1. Creating a Booking (Passenger App)
```dart
final bookingService = BookingService();
final booking = Booking(/* booking details */);

// This automatically updates van occupancy and status
String bookingId = await bookingService.createBooking(booking);
```

### 2. Updating Booking Status (Admin)
```dart
final bookingService = BookingService();

// This updates both booking and van occupancy
await bookingService.updateBookingStatusWithVanUpdate(
  bookingId, 
  'cancelled'
);
```

### 3. Manual Occupancy Update (Admin)
```dart
final vanService = VanService();

// This automatically checks and updates status if needed
await vanService.updateVanOccupancy(vanId, newOccupancy);
```

### 4. Getting Available Vans (Passenger App)
```dart
final vanService = VanService();

// Returns stream of vans that can accept bookings (excludes full vans)
Stream<List<Van>> availableVans = vanService.getAvailableVansForBooking();
```

## Status Flow Diagram

```
Booking Created/Updated
        ↓
Update Van Occupancy
        ↓
Check Occupancy vs Capacity
        ↓
    Full? ────── Yes ────→ Set Status to "full"
        ↓                         ↓
        No                Van not bookable in app
        ↓
Keep/Restore Bookable Status
        ↓
Van remains bookable
```

## Benefits

1. **Prevents Overbooking**: Automatically prevents new bookings when van is full
2. **Real-time Updates**: Status reflects actual occupancy immediately
3. **Passenger App Safety**: Users can't attempt to book full vans
4. **Admin Visibility**: Clear indicators show which vans are at capacity
5. **Automatic Management**: Reduces manual status management workload

## Configuration

### Status Priorities
1. `full` - Highest priority when capacity reached
2. `boarding` - For vans assigned to routes with available capacity
3. `in_queue` - For unassigned vans with available capacity

### Visual Indicators
- **Green**: 0-70% occupancy (available)
- **Amber**: 71-90% occupancy (nearly full)
- **Red**: 91-100% occupancy (full/nearly full)

## Integration Points

### Passenger Mobile App
- Use `getAvailableVansForBooking()` to get bookable vans only
- Call `checkAndUpdateVanStatusAfterBooking()` after successful bookings

### Admin Web Panel
- Manual occupancy adjustments automatically update status
- "Update All Statuses" button for system-wide refresh
- Visual progress bars show real-time occupancy

### Backend Systems
- Firestore triggers can call status update methods
- Scheduled functions can perform daily status validation
- API endpoints can integrate with external booking systems

## Testing

To test the automatic status update system:

1. **Create Test Bookings**: Add bookings until van reaches capacity
2. **Verify Status Change**: Confirm van status changes to "full"
3. **Check Passenger App**: Verify full van doesn't appear in available list
4. **Cancel Bookings**: Remove bookings and verify status restores
5. **Manual Override**: Test admin manual occupancy adjustments

## Future Enhancements

1. **Schedule-Based Occupancy**: Track occupancy per trip/schedule
2. **Predictive Status**: Mark vans as "nearly full" before reaching capacity
3. **Automated Alerts**: Notify when vans approach full capacity
4. **Integration APIs**: Webhook notifications for status changes
5. **Analytics**: Track occupancy patterns and optimization opportunities