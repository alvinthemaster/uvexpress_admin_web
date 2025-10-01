import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  bool _isDrawerOpen = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isDrawerOpen ? 280 : 70,
            child: _buildSidebar(),
          ),
          
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: Container(
                    color: Colors.grey[50],
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final currentRoute = GoRouterState.of(context).uri.toString();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo Header
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
            child: Row(
              children: [
                Icon(
                  Icons.directions_bus,
                  color: Theme.of(context).primaryColor,
                  size: 32,
                ),
                if (_isDrawerOpen) ...[
                  const SizedBox(width: AppConstants.smallPadding),
                  Expanded(
                    child: Text(
                      'UVExpress',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppConstants.smallPadding),
              children: [
                _buildNavItem(
                  icon: Icons.dashboard,
                  label: AppStrings.dashboard,
                  route: AppConstants.dashboardRoute,
                  isSelected: currentRoute == AppConstants.dashboardRoute,
                ),
                _buildNavItem(
                  icon: Icons.directions_bus,
                  label: AppStrings.vans,
                  route: AppConstants.vansRoute,
                  isSelected: currentRoute == AppConstants.vansRoute,
                ),
                _buildNavItem(
                  icon: Icons.book_online,
                  label: AppStrings.bookings,
                  route: AppConstants.bookingsRoute,
                  isSelected: currentRoute == AppConstants.bookingsRoute,
                ),
                _buildNavItem(
                  icon: Icons.route,
                  label: AppStrings.routes,
                  route: AppConstants.routesRoute,
                  isSelected: currentRoute == AppConstants.routesRoute,
                ),
                _buildNavItem(
                  icon: Icons.discount,
                  label: AppStrings.discounts,
                  route: AppConstants.discountsRoute,
                  isSelected: currentRoute == AppConstants.discountsRoute,
                ),
                _buildNavItem(
                  icon: Icons.analytics,
                  label: AppStrings.analytics,
                  route: AppConstants.analyticsRoute,
                  isSelected: currentRoute == AppConstants.analyticsRoute,
                ),
                
                const SizedBox(height: AppConstants.defaultPadding),
                if (_isDrawerOpen)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
                    child: Text(
                      'SYSTEM',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                
                _buildNavItem(
                  icon: Icons.settings,
                  label: AppStrings.settings,
                  route: AppConstants.settingsRoute,
                  isSelected: currentRoute == AppConstants.settingsRoute,
                ),
              ],
            ),
          ),
          
          // User Profile Section
          const Divider(height: 1),
          _buildUserProfile(),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String route,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          onTap: () => context.go(route),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.defaultPadding,
              vertical: AppConstants.smallPadding + 4,
            ),
            decoration: BoxDecoration(
              color: isSelected 
                  ? Theme.of(context).primaryColor.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
              border: isSelected
                  ? Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected 
                      ? Theme.of(context).primaryColor
                      : Colors.grey[600],
                ),
                if (_isDrawerOpen) ...[
                  const SizedBox(width: AppConstants.smallPadding + 4),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected 
                            ? Theme.of(context).primaryColor
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Menu Toggle Button
          IconButton(
            onPressed: () {
              setState(() {
                _isDrawerOpen = !_isDrawerOpen;
              });
            },
            icon: const Icon(Icons.menu),
            tooltip: _isDrawerOpen ? 'Collapse sidebar' : 'Expand sidebar',
          ),
          
          const SizedBox(width: AppConstants.defaultPadding),
          
          // Page Title
          Expanded(
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                String pageTitle = _getPageTitle(GoRouterState.of(context).uri.toString());
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      pageTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (authProvider.adminUser != null)
                      Text(
                        'Welcome back, ${authProvider.adminUser!.name}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          
          // Action Buttons
          IconButton(
            onPressed: () {
              // TODO: Implement notifications
            },
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
          ),
          
          const SizedBox(width: AppConstants.smallPadding),
          
          // User Menu
          _buildUserMenu(),
          
          const SizedBox(width: AppConstants.defaultPadding),
        ],
      ),
    );
  }

  Widget _buildUserProfile() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.adminUser == null) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  authProvider.adminUser!.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_isDrawerOpen) ...[
                const SizedBox(width: AppConstants.smallPadding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        authProvider.adminUser!.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        authProvider.adminUser!.role.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserMenu() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return PopupMenuButton<String>(
          offset: const Offset(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.smallPadding,
              vertical: AppConstants.smallPadding,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    authProvider.adminUser?.name[0].toUpperCase() ?? '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.smallPadding),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: const Row(
                children: [
                  Icon(Icons.person_outline),
                  SizedBox(width: AppConstants.smallPadding),
                  Text('Profile'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'settings',
              child: const Row(
                children: [
                  Icon(Icons.settings_outlined),
                  SizedBox(width: AppConstants.smallPadding),
                  Text('Settings'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red[600]),
                  const SizedBox(width: AppConstants.smallPadding),
                  Text('Logout', style: TextStyle(color: Colors.red[600])),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'profile':
                // TODO: Navigate to profile
                break;
              case 'settings':
                context.go(AppConstants.settingsRoute);
                break;
              case 'logout':
                authProvider.signOut();
                break;
            }
          },
        );
      },
    );
  }

  String _getPageTitle(String route) {
    switch (route) {
      case AppConstants.dashboardRoute:
        return AppStrings.dashboard;
      case AppConstants.vansRoute:
        return AppStrings.vanManagement;
      case AppConstants.bookingsRoute:
        return AppStrings.bookingManagement;
      case AppConstants.routesRoute:
        return AppStrings.routeManagement;
      case AppConstants.discountsRoute:
        return AppStrings.discountManagement;
      case AppConstants.analyticsRoute:
        return AppStrings.analytics;
      case AppConstants.settingsRoute:
        return AppStrings.settings;
      default:
        return AppStrings.dashboard;
    }
  }
}