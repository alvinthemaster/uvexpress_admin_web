/// Van Status Constants
///
/// Defines standardized status values for van management
/// to ensure consistency between admin panel and mobile app
/// Prioritizes mobile app expected values

class VanStatus {
  // PRIMARY statuses (expected by mobile app) - USE THESE
  static const String boarding = 'boarding';
  static const String inQueue = 'in_queue';
  static const String maintenance = 'maintenance';

  // Secondary statuses (for compatibility)
  static const String inTransit = 'in_transit';
  static const String inactive = 'inactive';

  // Legacy statuses (for backward compatibility only)
  static const String active = 'active';
  static const String ready = 'ready';
  static const String available = 'available';
  static const String loading = 'loading';
  static const String offline = 'offline';
  static const String busy = 'busy';
  static const String occupied = 'occupied';
  static const String full = 'full';
  static const String disabled = 'disabled';

  // All valid statuses (mobile app first)
  static const List<String> allStatuses = [
    boarding, // Mobile app primary
    inQueue, // Mobile app primary
    maintenance, // Mobile app primary
    inTransit,
    inactive,
    // Legacy statuses below
    active,
    ready,
    available,
    loading,
    offline,
    busy,
    occupied,
    full,
    disabled,
  ];

  // Status display mappings (mobile app values return exact display)
  static const Map<String, String> statusDisplayMap = {
    // Mobile app primary statuses (exact match)
    boarding: 'Boarding', // Mobile app: boarding -> Boarding
    inQueue: 'Ready', // Mobile app: in_queue -> Ready
    maintenance: 'Maintenance', // Mobile app: maintenance -> Maintenance
    inactive: 'Inactive', // Mobile app: inactive -> Inactive

    // Secondary statuses
    inTransit: 'In Transit', // in_transit -> In Transit

    // Legacy admin panel statuses (backward compatibility)
    active: 'Ready', // Admin legacy -> mobile equivalent (map to Ready)
    ready: 'Ready',
    available: 'Ready',
    loading: 'Boarding', // Loading is similar to boarding
    offline: 'Inactive',
    disabled: 'Inactive',
    busy: 'Busy',
    occupied: 'Busy',
    full: 'Full', // Full status - not bookable

    // Alternative formats (unique keys only)
    'in-queue': 'Ready', // Alternative dash format
    'queue': 'Ready',
    'in-transit': 'In Transit', // Alternative dash format
    'under_maintenance': 'Maintenance',
    'under-maintenance': 'Maintenance',
    'transit': 'In Transit',
    'traveling': 'In Transit',
    'departing': 'In Transit',
  };

  // Bookable statuses (mobile app priority) - excludes full vans
  static const List<String> bookableStatuses = [
    // Mobile app primary bookable statuses
    boarding, // Mobile app: boarding is bookable
    inQueue, // Mobile app: in_queue is bookable

    // Legacy admin panel bookable statuses
    active,
    ready,
    available,

    // Alternative formats
    'in-queue',
    'queue',
    // Note: 'full' is intentionally excluded from bookable statuses
  ];
}
