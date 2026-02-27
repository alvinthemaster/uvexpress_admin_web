import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/document_delivery_model.dart';
import '../services/document_delivery_service.dart';
import '../utils/constants.dart';

class DocumentDeliveryScreen extends StatefulWidget {
  const DocumentDeliveryScreen({super.key});

  @override
  State<DocumentDeliveryScreen> createState() => _DocumentDeliveryScreenState();
}

class _DocumentDeliveryScreenState extends State<DocumentDeliveryScreen> {
  final DocumentDeliveryService _service = DocumentDeliveryService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedStatusFilter = 'all';
  String _selectedPaymentFilter = 'all';
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';

  final List<String> _statusOptions = [
    'all',
    'pending',
    'picked_up',
    'in_transit',
    'delivered',
    'cancelled',
  ];

  final List<String> _paymentOptions = [
    'all',
    'unpaid',
    'paid',
    'failed',
    'refunded',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
            Expanded(child: _buildDeliveriesList()),
          ],
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Document Deliveries',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }

  // ─── Filters ─────────────────────────────────────────────────────────────────
  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            Row(
              children: [
                // Search
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search by sender, recipient, tracking #...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value.trim().toLowerCase());
                    },
                  ),
                ),
                const SizedBox(width: AppConstants.defaultPadding),

                // Delivery Status Filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Status',
                      border: OutlineInputBorder(),
                    ),
                    items: _statusOptions
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(_formatStatus(s)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedStatusFilter = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppConstants.defaultPadding),

                // Payment Status Filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedPaymentFilter,
                    decoration: const InputDecoration(
                      labelText: 'Payment Status',
                      border: OutlineInputBorder(),
                    ),
                    items: _paymentOptions
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(_formatStatus(s)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPaymentFilter = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _selectedDateRange != null
                        ? '${DateFormat('MMM dd').format(_selectedDateRange!.start)} – ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}'
                        : 'Select Date Range',
                  ),
                ),
                if (_selectedDateRange != null) ...[
                  const SizedBox(width: AppConstants.smallPadding),
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedDateRange = null),
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear'),
                  ),
                ],
                const Spacer(),
                Text(
                  'Filters applied: ${_getActiveFiltersCount()}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Deliveries List ──────────────────────────────────────────────────────────
  Widget _buildDeliveriesList() {
    return StreamBuilder<List<DocumentDelivery>>(
      stream: _getFilteredStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: AppConstants.defaultPadding),
                Text('Error loading deliveries: ${snapshot.error}'),
                const SizedBox(height: AppConstants.defaultPadding),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final all = snapshot.data ?? [];
        final filtered = _applySearchFilter(all);

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: AppConstants.defaultPadding),
                Text(
                  'No document deliveries found',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: AppConstants.smallPadding),
                Text(
                  'Try adjusting your filters or search criteria',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
              ],
            ),
          );
        }

        return Card(
          child: Column(
            children: [
              _buildTableHeader(),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _buildDeliveryRow(filtered[index]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Table Header ─────────────────────────────────────────────────────────────
  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: const Row(
        children: [
          Expanded(
              flex: 2,
              child: Text('Tracking / ID',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 2,
              child: Text('Sender',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 2,
              child: Text('Recipient',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 2,
              child: Text('Document',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 1,
              child: Text('Date',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 1,
              child: Text('Amount',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 1,
              child: Text('Status',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 1,
              child: Text('Actions',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  // ─── Table Row ────────────────────────────────────────────────────────────────
  Widget _buildDeliveryRow(DocumentDelivery delivery) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          // Tracking / ID
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  delivery.trackingNumber != null &&
                          delivery.trackingNumber!.isNotEmpty
                      ? delivery.trackingNumber!
                      : 'ID: ${delivery.id.length > 8 ? delivery.id.substring(0, 8) : delivery.id}...',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(delivery.paymentMethod,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),

          // Sender
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(delivery.senderName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(delivery.senderPhone,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                if (delivery.senderEmail.isNotEmpty &&
                    !delivery.senderEmail.contains('@admin.'))
                  Text(delivery.senderEmail,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),

          // Recipient
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(delivery.receiverName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(delivery.recipientPhone,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                if (delivery.recipientAddress.isNotEmpty)
                  Text(
                    delivery.recipientAddress,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Document Description
          Expanded(
            flex: 2,
            child: Text(
              delivery.documentType,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),

          // Date
          Expanded(
            flex: 1,
            child: Text(
              DateFormat('MMM dd, yyyy').format(delivery.createdAt),
              style: const TextStyle(fontSize: 12),
            ),
          ),

          // Amount
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppConstants.currencySymbol}${delivery.paymentAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (delivery.paymentAmount != delivery.bookingFee)
                  Text(
                    'Fee: ${AppConstants.currencySymbol}${delivery.bookingFee.toStringAsFixed(2)}',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),

          // Status chips
          Expanded(
            flex: 1,
            child: Column(
              children: [
                _buildStatusChip(delivery.deliveryStatus, isDelivery: true),
                const SizedBox(height: 4),
                _buildStatusChip(delivery.paymentStatus, isDelivery: false),
              ],
            ),
          ),

          // Actions
          Expanded(
            flex: 1,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _showDeliveryDetails(delivery),
                  icon: const Icon(Icons.visibility),
                  tooltip: 'View Details',
                ),
                if (delivery.paymentStatus == 'unpaid' ||
                    delivery.paymentStatus == 'pending')
                  Tooltip(
                    message: 'Mark as Paid',
                    child: TextButton.icon(
                      onPressed: () async {
                        try {
                          await _service.updatePaymentStatus(
                              delivery.id, 'paid');
                          _showSnack('Payment marked as Paid');
                        } catch (e) {
                          _showSnack('Error: $e', isError: true);
                        }
                      },
                      icon: const Icon(Icons.payment, size: 15),
                      label: const Text('Paid',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) =>
                      _handleDeliveryAction(value, delivery),
                  itemBuilder: (context) {
                    final items = <PopupMenuEntry<String>>[];

                    if (delivery.deliveryStatus == 'pending') {
                      items.add(const PopupMenuItem(
                          value: 'picked_up',
                          child: Row(children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 16, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Mark Picked Up'),
                          ])));
                    }
                    if (delivery.deliveryStatus == 'picked_up') {
                      items.add(const PopupMenuItem(
                          value: 'in_transit',
                          child: Row(children: [
                            Icon(Icons.local_shipping_outlined,
                                size: 16, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Mark In Transit'),
                          ])));
                    }
                    if (delivery.deliveryStatus == 'in_transit') {
                      items.add(const PopupMenuItem(
                          value: 'delivered',
                          child: Row(children: [
                            Icon(Icons.check_circle_outline,
                                size: 16, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Mark Delivered'),
                          ])));
                    }
                    if (delivery.paymentStatus == 'unpaid') {
                      items.add(const PopupMenuItem(
                          value: 'mark_paid',
                          child: Row(children: [
                            Icon(Icons.payment, size: 16, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Mark Paid'),
                          ])));
                    }
                    if (delivery.deliveryStatus != 'cancelled' &&
                        delivery.deliveryStatus != 'delivered') {
                      items.add(const PopupMenuDivider());
                      items.add(const PopupMenuItem(
                          value: 'cancel',
                          child: Row(children: [
                            Icon(Icons.cancel_outlined,
                                size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Cancel',
                                style: TextStyle(color: Colors.red)),
                          ])));
                    }
                    items.add(const PopupMenuDivider());
                    items.add(const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline,
                              size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ])));

                    return items;
                  },
                  child: const Icon(Icons.more_vert),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Status Chip ──────────────────────────────────────────────────────────────
  Widget _buildStatusChip(String status, {required bool isDelivery}) {
    Color color;

    if (isDelivery) {
      switch (status.toLowerCase()) {
        case 'delivered':
          color = Colors.green;
          break;
        case 'in_transit':
          color = Colors.blue;
          break;
        case 'picked_up':
          color = Colors.teal;
          break;
        case 'pending':
          color = Colors.orange;
          break;
        case 'cancelled':
          color = Colors.red;
          break;
        default:
          color = Colors.grey;
      }
    } else {
      switch (status.toLowerCase()) {
        case 'paid':
          color = Colors.green;
          break;
        case 'unpaid':
        case 'pending':
          color = Colors.orange;
          break;
        case 'failed':
          color = Colors.red;
          break;
        case 'refunded':
          color = Colors.purple;
          break;
        default:
          color = Colors.grey;
      }
    }

    final String label = (!isDelivery &&
            (status.toLowerCase() == 'unpaid' ||
                status.toLowerCase() == 'pending'))
        ? 'Unpaid'
        : _formatStatus(status);

    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  // ─── Details Dialog ───────────────────────────────────────────────────────────
  void _showDeliveryDetails(DocumentDelivery delivery) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            'Delivery Details – ${delivery.trackingNumber ?? delivery.id.substring(0, 8)}...'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailSection('Sender Information', [
                  'Name: ${delivery.senderName}',
                  'Phone: ${delivery.senderPhone}',
                  if (delivery.senderEmail.isNotEmpty &&
                      !delivery.senderEmail.contains('@admin.'))
                    'Email: ${delivery.senderEmail}',
                ]),
                _buildDetailSection('Recipient Information', [
                  'Name: ${delivery.receiverName}',
                  'Phone: ${delivery.recipientPhone}',
                  'Address: ${delivery.recipientAddress}',
                ]),
                _buildDetailSection('Document Information', [
                  'Description: ${delivery.documentType}',
                  if (delivery.trackingNumber != null &&
                      delivery.trackingNumber!.isNotEmpty)
                    'Tracking #: ${delivery.trackingNumber}',
                ]),
                _buildDetailSection('Delivery Information', [
                  'Status: ${_formatStatus(delivery.deliveryStatus)}',
                  'Created: ${DateFormat('MMM dd, yyyy h:mm a').format(delivery.createdAt)}',
                  if (delivery.deliveryDate != null)
                    'Delivered: ${DateFormat('MMM dd, yyyy h:mm a').format(delivery.deliveryDate!)}',
                  if (delivery.vanPlateNumber != null &&
                      delivery.vanPlateNumber!.isNotEmpty)
                    'Van: ${delivery.vanPlateNumber}',
                  if (delivery.driverName != null &&
                      delivery.driverName!.isNotEmpty)
                    'Driver: ${delivery.driverName}',
                  if (delivery.driverContact != null &&
                      delivery.driverContact!.isNotEmpty)
                    'Driver Contact: ${delivery.driverContact}',
                  if (delivery.notes != null && delivery.notes!.isNotEmpty)
                    'Notes: ${delivery.notes}',
                ]),
                _buildDetailSection('Payment Information', [
                  'Method: ${delivery.paymentMethod}',
                  'Delivery Fee: ${AppConstants.currencySymbol}${delivery.bookingFee.toStringAsFixed(2)}',
                  'Total: ${AppConstants.currencySymbol}${delivery.paymentAmount.toStringAsFixed(2)}',
                  'Payment Status: ${_formatStatus(delivery.paymentStatus)}',
                ]),
                if (delivery.deliveryStatus == 'cancelled') ...[
                  _buildDetailSection('Cancellation Information', [
                    if (delivery.cancelledBy != null)
                      'Cancelled By: ${delivery.cancelledBy}',
                    if (delivery.cancellationReason != null)
                      'Reason: ${delivery.cancellationReason}',
                    if (delivery.cancelledAt != null)
                      'Cancelled At: ${DateFormat('MMM dd, yyyy h:mm a').format(delivery.cancelledAt!)}',
                  ]),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<String> details) {
    if (details.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...details.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(d),
            )),
        const SizedBox(height: 16),
      ],
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────────
  void _handleDeliveryAction(String action, DocumentDelivery delivery) async {
    try {
      switch (action) {
        case 'picked_up':
          await _service.updateDeliveryStatus(delivery.id, 'picked_up');
          _showSnack('Marked as Picked Up');
          break;
        case 'in_transit':
          await _service.updateDeliveryStatus(delivery.id, 'in_transit');
          _showSnack('Marked as In Transit');
          break;
        case 'delivered':
          await _service.markAsDelivered(delivery.id);
          _showSnack('Marked as Delivered');
          break;
        case 'mark_paid':
          await _service.updatePaymentStatus(delivery.id, 'paid');
          _showSnack('Payment marked as Paid');
          break;
        case 'cancel':
          await _service.cancelDelivery(delivery.id, 'admin', 'Cancelled by admin');
          _showSnack('Delivery cancelled');
          break;
        case 'delete':
          _showDeleteConfirmation(delivery);
          break;
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  void _showDeleteConfirmation(DocumentDelivery delivery) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Delivery'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this delivery?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tracking: ${delivery.trackingNumber ?? delivery.id.substring(0, 8)}'),
                  Text('Sender: ${delivery.senderName}'),
                  Text('Receiver: ${delivery.receiverName}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await _service.deleteDelivery(delivery.id);
                _showSnack('Delivery deleted successfully');
              } catch (e) {
                _showSnack('Error deleting delivery: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  Stream<List<DocumentDelivery>> _getFilteredStream() {
    if (_selectedDateRange != null) {
      return _service.getDeliveriesByDateRange(
          _selectedDateRange!.start, _selectedDateRange!.end);
    } else if (_selectedStatusFilter != 'all') {
      return _service.getDeliveriesByStatus(_selectedStatusFilter);
    } else if (_selectedPaymentFilter != 'all') {
      return _service.getDeliveriesByPaymentStatus(_selectedPaymentFilter);
    } else {
      return _service.getDeliveriesStream();
    }
  }

  List<DocumentDelivery> _applySearchFilter(List<DocumentDelivery> items) {
    if (_searchQuery.isEmpty) return items;
    return items.where((d) {
      return d.senderName.toLowerCase().contains(_searchQuery) ||
          d.receiverName.toLowerCase().contains(_searchQuery) ||
          d.senderPhone.toLowerCase().contains(_searchQuery) ||
          d.recipientPhone.toLowerCase().contains(_searchQuery) ||
          d.id.toLowerCase().contains(_searchQuery) ||
          (d.trackingNumber?.toLowerCase().contains(_searchQuery) ?? false) ||
          d.documentType.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  String _formatStatus(String status) {
    if (status == 'all') return 'All';
    return status
        .split('_')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  int _getActiveFiltersCount() {
    int count = 0;
    if (_selectedStatusFilter != 'all') count++;
    if (_selectedPaymentFilter != 'all') count++;
    if (_selectedDateRange != null) count++;
    if (_searchQuery.isNotEmpty) count++;
    return count;
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) setState(() => _selectedDateRange = picked);
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }
}
