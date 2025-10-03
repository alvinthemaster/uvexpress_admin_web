import 'package:intl/intl.dart';

class AppConstants {
  // App Information
  static const String appName = 'Godtrasco Admin Panel';
  static const String appVersion = '1.0.0';

  // Colors
  static const int primaryColorValue = 0xFF1976D2;
  static const int secondaryColorValue = 0xFF03DAC6;
  static const int errorColorValue = 0xFFB00020;
  static const int warningColorValue = 0xFFF57C00;
  static const int successColorValue = 0xFF4CAF50;

  // Dimensions
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double defaultBorderRadius = 8.0;
  static const double cardElevation = 4.0;

  // Navigation
  static const String dashboardRoute = '/dashboard';
  static const String loginRoute = '/login';
  static const String vansRoute = '/vans';
  static const String bookingsRoute = '/bookings';
  static const String routesRoute = '/routes';
  static const String discountsRoute = '/discounts';
  static const String analyticsRoute = '/analytics';
  static const String settingsRoute = '/settings';

  // Firebase Collections
  static const String vansCollection = 'vans';
  static const String routesCollection = 'routes';
  static const String bookingsCollection = 'bookings';
  static const String discountsCollection = 'discounts';
  static const String schedulesCollection = 'schedules';
  static const String adminUsersCollection = 'admin_users';
  static const String analyticsCollection = 'analytics';

  // Van Status
  static const String vanStatusActive = 'active';
  static const String vanStatusInactive = 'inactive';
  static const String vanStatusMaintenance = 'maintenance';
  static const String vanStatusInTransit = 'in_transit';

  // Booking Status
  static const String bookingStatusActive = 'active';
  static const String bookingStatusCompleted = 'completed';
  static const String bookingStatusCancelled = 'cancelled';
  static const String bookingStatusConfirmed = 'confirmed';

  // Payment Status
  static const String paymentStatusPending = 'pending';
  static const String paymentStatusPaid = 'paid';
  static const String paymentStatusFailed = 'failed';
  static const String paymentStatusRefunded = 'refunded';

  // Payment Methods
  static const String paymentMethodGCash = 'GCash';
  static const String paymentMethodMaya = 'Maya';
  static const String paymentMethodPhysical = 'Physical Payment';
  static const String paymentMethodPayPal = 'PayPal';

  // Discount Types
  static const String discountTypePercentage = 'percentage';
  static const String discountTypeFixed = 'fixed';

  // Eligibility Types
  static const String eligibilityStudent = 'student';
  static const String eligibilitySenior = 'senior';
  static const String eligibilityPWD = 'pwd';
  static const String eligibilityAll = 'all';

  // Admin Roles
  static const String roleSuperAdmin = 'super_admin';
  static const String roleRouteManager = 'route_manager';
  static const String roleFinanceManager = 'finance_manager';
  static const String roleOperationsManager = 'operations_manager';
  static const String roleAnalyst = 'analyst';

  // Permissions
  static const String permissionAll = 'all';
  static const String permissionReadOnly = 'read_only';
  static const String permissionVanManagement = 'van_management';
  static const String permissionRouteManagement = 'route_management';
  static const String permissionBookingManagement = 'booking_management';
  static const String permissionDiscountManagement = 'discount_management';
  static const String permissionAnalytics = 'analytics';

  // Date Formats
  static final DateFormat dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat timeFormat = DateFormat('HH:mm');
  static final DateFormat displayDateFormat = DateFormat('MMM dd, yyyy');
  static final DateFormat displayDateTimeFormat =
      DateFormat('MMM dd, yyyy HH:mm');

  // Number Formats
  static final NumberFormat currencyFormat =
      NumberFormat.currency(symbol: '₱', decimalDigits: 2);
  static final NumberFormat percentFormat = NumberFormat.percentPattern();
  static final NumberFormat compactFormat = NumberFormat.compact();

  // Validation
  static const int minPasswordLength = 6;
  static const int maxNameLength = 50;
  static const int maxDescriptionLength = 500;
  static const int maxPlateNumberLength = 10;
  static const int maxPhoneLength = 15;

  // API Limits
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  static const int defaultTimeout = 30; // seconds

  // Local Storage Keys
  static const String userPrefsKey = 'user_preferences';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';
  static const String lastLoginKey = 'last_login';
}

class AppStrings {
  // General
  static const String appTitle = 'Godtrasco Admin Panel';
  static const String loading = 'Loading...';
  static const String error = 'Error';
  static const String success = 'Success';
  static const String warning = 'Warning';
  static const String info = 'Information';
  static const String confirm = 'Confirm';
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String add = 'Add';
  static const String view = 'View';
  static const String search = 'Search';
  static const String filter = 'Filter';
  static const String refresh = 'Refresh';
  static const String export = 'Export';
  static const String print = 'Print';
  static const String yes = 'Yes';
  static const String no = 'No';
  static const String ok = 'OK';
  static const String close = 'Close';

  // Authentication
  static const String login = 'Login';
  static const String logout = 'Logout';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String forgotPassword = 'Forgot Password?';
  static const String resetPassword = 'Reset Password';
  static const String signIn = 'Sign In';
  static const String welcome = 'Welcome';
  static const String accessDenied = 'Access Denied';
  static const String adminRequired = 'Admin privileges required';

  // Navigation
  static const String dashboard = 'Dashboard';
  static const String vans = 'Vans';
  static const String bookings = 'Bookings';
  static const String routes = 'Routes';
  static const String discounts = 'Discounts';
  static const String analytics = 'Analytics';
  static const String settings = 'Settings';
  static const String profile = 'Profile';

  // Van Management
  static const String vanManagement = 'Van Management';
  static const String addVan = 'Add Van';
  static const String editVan = 'Edit Van';
  static const String deleteVan = 'Delete Van';
  static const String plateNumber = 'Plate Number';
  static const String capacity = 'Capacity';
  static const String driver = 'Driver';
  static const String status = 'Status';
  static const String queuePosition = 'Queue Position';
  static const String maintenance = 'Maintenance';
  static const String active = 'Active';
  static const String inactive = 'Inactive';

  // Booking Management
  static const String bookingManagement = 'Booking Management';
  static const String bookingId = 'Booking ID';
  static const String passenger = 'Passenger';
  static const String route = 'Route';
  static const String departureTime = 'Departure Time';
  static const String seats = 'Seats';
  static const String amount = 'Amount';
  static const String paymentMethod = 'Payment Method';
  static const String paymentStatus = 'Payment Status';
  static const String bookingStatus = 'Booking Status';

  // Route Management
  static const String routeManagement = 'Route Management';
  static const String addRoute = 'Add Route';
  static const String editRoute = 'Edit Route';
  static const String deleteRoute = 'Delete Route';
  static const String origin = 'Origin';
  static const String destination = 'Destination';
  static const String basePrice = 'Base Price';
  static const String duration = 'Duration';
  static const String waypoints = 'Waypoints';

  // Discount Management
  static const String discountManagement = 'Discount Management';
  static const String addDiscount = 'Add Discount';
  static const String editDiscount = 'Edit Discount';
  static const String deleteDiscount = 'Delete Discount';
  static const String discountName = 'Discount Name';
  static const String discountType = 'Discount Type';
  static const String discountValue = 'Discount Value';
  static const String eligibility = 'Eligibility';
  static const String validFrom = 'Valid From';
  static const String validTo = 'Valid To';
  static const String usage = 'Usage';

  // Analytics
  static const String totalBookings = 'Total Bookings';
  static const String totalRevenue = 'Total Revenue';
  static const String totalDiscounts = 'Total Discounts';
  static const String averageFare = 'Average Fare';
  static const String passengerCount = 'Passenger Count';
  static const String peakHours = 'Peak Hours';
  static const String dailyReport = 'Daily Report';
  static const String weeklyReport = 'Weekly Report';
  static const String monthlyReport = 'Monthly Report';

  // Messages
  static const String noDataAvailable = 'No data available';
  static const String operationSuccessful = 'Operation completed successfully';
  static const String operationFailed = 'Operation failed';
  static const String deleteConfirmation =
      'Are you sure you want to delete this item?';
  static const String unsavedChanges =
      'You have unsaved changes. Do you want to save before leaving?';
  static const String networkError =
      'Network error. Please check your connection.';
  static const String unknownError =
      'An unknown error occurred. Please try again.';

  // Validation Messages
  static const String fieldRequired = 'This field is required';
  static const String invalidEmail = 'Please enter a valid email address';
  static const String passwordTooShort =
      'Password must be at least 6 characters';
  static const String invalidPhoneNumber = 'Please enter a valid phone number';
  static const String invalidAmount = 'Please enter a valid amount';
  static const String invalidDate = 'Please enter a valid date';
}
