import 'package:flutter/material.dart';
import '../models/route_model.dart' as route_model;
import '../models/van_model.dart';
import '../services/route_service.dart';
import '../services/van_service.dart';
import '../utils/constants.dart';

class RouteManagementScreen extends StatefulWidget {
  const RouteManagementScreen({super.key});

  @override
  State<RouteManagementScreen> createState() => _RouteManagementScreenState();
}

class _RouteManagementScreenState extends State<RouteManagementScreen> {
  final RouteService _routeService = RouteService();
  final VanService _vanService = VanService();
  List<route_model.Route> _routes = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final routesStream = _routeService.getRoutesStream();
      routesStream.listen((routes) {
        if (mounted) {
          setState(() {
            _routes = routes;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      print('Error loading routes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<route_model.Route> get filteredRoutes {
    if (_searchQuery.isEmpty) return _routes;
    return _routes.where((route) =>
      route.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      route.origin.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      route.destination.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: AppConstants.largePadding),
            _buildSearchBar(),
            const SizedBox(height: AppConstants.defaultPadding),
            Expanded(child: _buildRoutesList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Route Management',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showAddRouteDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add Route'),
        ),
        const SizedBox(width: AppConstants.smallPadding),
        OutlinedButton.icon(
          onPressed: () => _createSampleRoutes(),
          icon: const Icon(Icons.data_object),
          label: const Text('Add Sample Routes'),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: const InputDecoration(
        hintText: 'Search routes by name, origin, or destination...',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildRoutesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final routes = filteredRoutes;

    if (routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.route,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Text(
              _searchQuery.isEmpty 
                ? 'No routes available. Create your first route!'
                : 'No routes found matching your search.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: routes.length,
      itemBuilder: (context, index) {
        final route = routes[index];
        return _buildRouteCard(route);
      },
    );
  }

  Widget _buildRouteCard(route_model.Route route) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
      child: ExpansionTile(
        title: Text(
          route.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${route.origin} → ${route.destination}'),
            Text('₱${route.basePrice.toStringAsFixed(2)} • ${route.estimatedDuration} minutes'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: route.isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                route.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: route.isActive ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: AppConstants.smallPadding),
            PopupMenuButton<String>(
              onSelected: (value) => _handleRouteAction(value, route),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: route.isActive ? 'deactivate' : 'activate',
                  child: Text(route.isActive ? 'Deactivate' : 'Activate'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route Details
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Waypoints: ${route.waypoints.join(', ')}'),
                          Text('Created: ${_formatDate(route.createdAt)}'),
                          Text('Updated: ${_formatDate(route.updatedAt)}'),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: AppConstants.defaultPadding),
                
                // Assigned Vans
                FutureBuilder<List<Van>>(
                  future: _vanService.getVansByRoute(route.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text('Loading assigned vans...');
                    }
                    
                    if (snapshot.hasError) {
                      return Text('Error loading vans: ${snapshot.error}');
                    }
                    
                    final assignedVans = snapshot.data ?? [];
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assigned Vans (${assignedVans.length}):',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppConstants.smallPadding),
                        if (assignedVans.isEmpty)
                          const Text('No vans assigned to this route')
                        else
                          ...assignedVans.map((van) => Padding(
                            padding: const EdgeInsets.only(left: 16, top: 4),
                            child: Text(
                              '• ${van.plateNumber} (${van.statusDisplay}) - Driver: ${van.driver.name}',
                            ),
                          )),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _handleRouteAction(String action, route_model.Route route) {
    switch (action) {
      case 'edit':
        _showEditRouteDialog(route);
        break;
      case 'activate':
      case 'deactivate':
        _toggleRouteStatus(route);
        break;
      case 'delete':
        _showDeleteConfirmation(route);
        break;
    }
  }

  void _showAddRouteDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddRouteDialog(),
    );
  }

  void _showEditRouteDialog(route_model.Route route) {
    showDialog(
      context: context,
      builder: (context) => AddRouteDialog(route: route),
    );
  }

  Future<void> _toggleRouteStatus(route_model.Route route) async {
    try {
      final updatedRoute = route.copyWith(
        isActive: !route.isActive,
        updatedAt: DateTime.now(),
      );
      
      await _routeService.updateRoute(route.id, updatedRoute);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Route ${route.name} ${updatedRoute.isActive ? 'activated' : 'deactivated'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating route: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(route_model.Route route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text('Are you sure you want to delete route "${route.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteRoute(route);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRoute(route_model.Route route) async {
    try {
      await _routeService.deleteRoute(route.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Route "${route.name}" deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting route: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createSampleRoutes() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Creating sample routes...'),
            ],
          ),
        ),
      );

      // Create sample routes
      final sampleRoutes = [
        route_model.Route(
          id: '',
          name: 'UV Express Route 1',
          origin: 'Cubao',
          destination: 'Alabang',
          basePrice: 50.0,
          estimatedDuration: 60,
          waypoints: ['EDSA', 'Makati', 'Muntinlupa'],
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        route_model.Route(
          id: '',
          name: 'UV Express Route 2',
          origin: 'Fairview',
          destination: 'Makati',
          basePrice: 45.0,
          estimatedDuration: 45,
          waypoints: ['Commonwealth', 'EDSA'],
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        route_model.Route(
          id: '',
          name: 'UV Express Route 3',
          origin: 'Antipolo',
          destination: 'Ortigas',
          basePrice: 40.0,
          estimatedDuration: 35,
          waypoints: ['Masinag', 'Cainta'],
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      for (final route in sampleRoutes) {
        await _routeService.addRoute(route);
      }

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sample routes created successfully! Added ${sampleRoutes.length} routes.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating sample routes: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

class AddRouteDialog extends StatefulWidget {
  final route_model.Route? route;

  const AddRouteDialog({super.key, this.route});

  @override
  State<AddRouteDialog> createState() => _AddRouteDialogState();
}

class _AddRouteDialogState extends State<AddRouteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _basePriceController = TextEditingController();
  final _estimatedDurationController = TextEditingController();
  final _waypointsController = TextEditingController();
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.route != null) {
      _nameController.text = widget.route!.name;
      _originController.text = widget.route!.origin;
      _destinationController.text = widget.route!.destination;
      _basePriceController.text = widget.route!.basePrice.toString();
      _estimatedDurationController.text = widget.route!.estimatedDuration.toString();
      _waypointsController.text = widget.route!.waypoints.join(', ');
      _isActive = widget.route!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _basePriceController.dispose();
    _estimatedDurationController.dispose();
    _waypointsController.dispose();
    super.dispose();
  }

  Future<void> _saveRoute() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final routeService = RouteService();
      final waypoints = _waypointsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final route = route_model.Route(
        id: widget.route?.id ?? '',
        name: _nameController.text.trim(),
        origin: _originController.text.trim(),
        destination: _destinationController.text.trim(),
        basePrice: double.parse(_basePriceController.text),
        estimatedDuration: int.parse(_estimatedDurationController.text),
        waypoints: waypoints,
        isActive: _isActive,
        createdAt: widget.route?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.route == null) {
        await routeService.addRoute(route);
      } else {
        await routeService.updateRoute(widget.route!.id, route);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.route == null 
                ? 'Route created successfully' 
                : 'Route updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving route: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.route == null ? 'Add New Route' : 'Edit Route',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              // Route Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Route Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Route name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Origin and Destination
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _originController,
                      decoration: const InputDecoration(
                        labelText: 'Origin *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Origin is required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _destinationController,
                      decoration: const InputDecoration(
                        labelText: 'Destination *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Destination is required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Base Price and Duration
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _basePriceController,
                      decoration: const InputDecoration(
                        labelText: 'Base Price (₱) *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Base price is required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid price';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _estimatedDurationController,
                      decoration: const InputDecoration(
                        labelText: 'Duration (minutes) *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Duration is required';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid duration';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Waypoints
              TextFormField(
                controller: _waypointsController,
                decoration: const InputDecoration(
                  labelText: 'Waypoints (comma-separated)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., EDSA, Makati, Alabang',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              // Active status
              Row(
                children: [
                  Checkbox(
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value ?? true;
                      });
                    },
                  ),
                  const Text('Route is active'),
                ],
              ),
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveRoute,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.route == null ? 'Add Route' : 'Update Route'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
