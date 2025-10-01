import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/van_provider.dart';
import '../models/van_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class VanManagementScreen extends StatefulWidget {
  const VanManagementScreen({super.key});

  @override
  State<VanManagementScreen> createState() => _VanManagementScreenState();
}

class _VanManagementScreenState extends State<VanManagementScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: AppConstants.defaultPadding),
            _buildFilters(),
            const SizedBox(height: AppConstants.defaultPadding),
            Expanded(child: _buildVansList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Van Management',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppConstants.smallPadding),
              Text(
                'Manage your fleet of vans and track their status',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showAddVanDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add Van'),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search vans by plate number or driver name...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        const SizedBox(width: AppConstants.defaultPadding),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String>(
            initialValue: _statusFilter,
            decoration: const InputDecoration(
              labelText: 'Status Filter',
              prefixIcon: Icon(Icons.filter_list),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Status')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
            ],
            onChanged: (value) {
              setState(() {
                _statusFilter = value ?? 'all';
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVansList() {
    return Consumer<VanProvider>(
      builder: (context, vanProvider, _) {
        List<Van> filteredVans = vanProvider.vans;

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          filteredVans = filteredVans.where((van) =>
              van.plateNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              van.driver.name.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();
        }

        // Apply status filter
        if (_statusFilter != 'all') {
          filteredVans = filteredVans.where((van) => van.status == _statusFilter).toList();
        }

        if (filteredVans.isEmpty) {
          return const Center(
            child: Text('No vans found matching your criteria'),
          );
        }

        return ListView.builder(
          itemCount: filteredVans.length,
          itemBuilder: (context, index) {
            final van = filteredVans[index];
            return _buildVanCard(van);
          },
        );
      },
    );
  }

  Widget _buildVanCard(Van van) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Row(
          children: [
            // Van Status Indicator
            Container(
              width: 8,
              height: 60,
              decoration: BoxDecoration(
                color: _getStatusColor(van.status),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: AppConstants.defaultPadding),
            
            // Van Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        van.plateNumber,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: AppConstants.smallPadding),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.smallPadding,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(van.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          AppHelpers.formatVanStatus(van.status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _getStatusColor(van.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.smallPadding),
                  Text('Driver: ${van.driver.name}'),
                  Text('Capacity: ${van.capacity} seats'),
                  Text('Queue Position: #${van.queuePosition}'),
                ],
              ),
            ),
            
            // Actions
            PopupMenuButton<String>(
              onSelected: (value) => _handleVanAction(value, van),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'move_up', child: Text('Move Up in Queue')),
                const PopupMenuItem(value: 'move_down', child: Text('Move to End')),
                const PopupMenuItem(value: 'maintenance', child: Text('Set Maintenance')),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'in_transit':
        return Colors.blue;
      case 'maintenance':
        return Colors.orange;
      case 'inactive':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _handleVanAction(String action, Van van) {
    final vanProvider = Provider.of<VanProvider>(context, listen: false);
    
    switch (action) {
      case 'edit':
        _showEditVanDialog(van);
        break;
      case 'move_up':
        vanProvider.moveVanToNext(van.id);
        break;
      case 'move_down':
        vanProvider.moveVanToEnd(van.id);
        break;
      case 'maintenance':
        _showMaintenanceDialog(van);
        break;
      case 'delete':
        _showDeleteConfirmation(van);
        break;
    }
  }

  void _showAddVanDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddVanDialog(),
    );
  }

  void _showEditVanDialog(Van van) {
    // TODO: Implement edit van dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Van'),
        content: Text('Edit van ${van.plateNumber} dialog will be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceDialog(Van van) {
    // TODO: Implement maintenance dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Maintenance Schedule'),
        content: Text('Maintenance schedule for ${van.plateNumber} will be set here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Van van) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Van'),
        content: Text('Are you sure you want to delete van ${van.plateNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<VanProvider>(context, listen: false).deleteVan(van.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class AddVanDialog extends StatefulWidget {
  const AddVanDialog({super.key});

  @override
  State<AddVanDialog> createState() => _AddVanDialogState();
}

class _AddVanDialogState extends State<AddVanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _plateNumberController = TextEditingController();
  final _capacityController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _driverLicenseController = TextEditingController();
  final _driverContactController = TextEditingController();
  
  String _selectedStatus = 'active';
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _plateNumberController.dispose();
    _capacityController.dispose();
    _driverNameController.dispose();
    _driverLicenseController.dispose();
    _driverContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppConstants.defaultBorderRadius),
                  topRight: Radius.circular(AppConstants.defaultBorderRadius),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_shipping,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: AppConstants.smallPadding),
                  Expanded(
                    child: Text(
                      'Add New Van',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Van Information Section
                      Text(
                        'Van Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),
                      
                      // Plate Number
                      TextFormField(
                        controller: _plateNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Plate Number *',
                          hintText: 'Enter van plate number (e.g., ABC-1234)',
                          prefixIcon: Icon(Icons.confirmation_number),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Plate number is required';
                          }
                          if (value.trim().length < 3) {
                            return 'Plate number must be at least 3 characters';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),
                      
                      // Capacity
                      TextFormField(
                        controller: _capacityController,
                        decoration: const InputDecoration(
                          labelText: 'Passenger Capacity *',
                          hintText: 'Enter maximum passenger capacity',
                          prefixIcon: Icon(Icons.people),
                          suffixText: 'passengers',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Capacity is required';
                          }
                          int? capacity = int.tryParse(value.trim());
                          if (capacity == null || capacity <= 0) {
                            return 'Enter a valid capacity greater than 0';
                          }
                          if (capacity > 50) {
                            return 'Capacity seems too high. Please verify.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),
                      
                      // Status
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Initial Status',
                          prefixIcon: Icon(Icons.info),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('Active - Ready for service')),
                          DropdownMenuItem(value: 'inactive', child: Text('Inactive - Not in service')),
                          DropdownMenuItem(value: 'maintenance', child: Text('Maintenance - Under repair')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value!;
                          });
                        },
                      ),
                      const SizedBox(height: AppConstants.largePadding),
                      
                      // Driver Information Section
                      Text(
                        'Driver Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),
                      
                      // Driver Name
                      TextFormField(
                        controller: _driverNameController,
                        decoration: const InputDecoration(
                          labelText: 'Driver Name *',
                          hintText: 'Enter driver full name',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Driver name is required';
                          }
                          if (value.trim().length < 2) {
                            return 'Driver name must be at least 2 characters';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),
                      
                      // Driver License
                      TextFormField(
                        controller: _driverLicenseController,
                        decoration: const InputDecoration(
                          labelText: 'Driver License Number *',
                          hintText: 'Enter driver license number',
                          prefixIcon: Icon(Icons.credit_card),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Driver license is required';
                          }
                          if (value.trim().length < 5) {
                            return 'License number must be at least 5 characters';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),
                      
                      // Driver Contact
                      TextFormField(
                        controller: _driverContactController,
                        decoration: const InputDecoration(
                          labelText: 'Driver Contact Number *',
                          hintText: 'Enter driver phone number',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Driver contact is required';
                          }
                          if (value.trim().length < 10) {
                            return 'Contact number must be at least 10 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),
                      
                      // Active Status
                      SwitchListTile(
                        title: const Text('Active Van'),
                        subtitle: const Text('Enable this van for passenger bookings'),
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Footer with Actions
            Container(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppConstants.defaultBorderRadius),
                  bottomRight: Radius.circular(AppConstants.defaultBorderRadius),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppConstants.smallPadding),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _addVan,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: Text(_isLoading ? 'Adding...' : 'Add Van'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.defaultPadding,
                        vertical: AppConstants.smallPadding,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addVan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final vanProvider = Provider.of<VanProvider>(context, listen: false);

      // Create driver object
      final driver = Driver(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _driverNameController.text.trim(),
        license: _driverLicenseController.text.trim(),
        contact: _driverContactController.text.trim(),
      );

      // Create van object
      final van = Van(
        id: '', // Will be set by Firestore
        plateNumber: _plateNumberController.text.trim().toUpperCase(),
        capacity: int.parse(_capacityController.text.trim()),
        driver: driver,
        status: _selectedStatus,
        queuePosition: 0, // Will be set by service
        isActive: _isActive,
        createdAt: DateTime.now(),
      );

      // Add the van
      await vanProvider.addVan(van);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: AppConstants.smallPadding),
              Expanded(
                child: Text('Van ${van.plateNumber} added successfully!'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: AppConstants.smallPadding),
              Expanded(
                child: Text('Error adding van: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}