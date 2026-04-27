import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/rental_van_listing_model.dart';
import '../models/van_rental_request_model.dart';
import '../models/van_model.dart';
import '../providers/rental_van_listing_provider.dart';
import '../providers/van_rental_request_provider.dart';
import '../providers/van_provider.dart';
import '../utils/constants.dart';

class VanRentalScreen extends StatefulWidget {
  const VanRentalScreen({super.key});

  @override
  State<VanRentalScreen> createState() => _VanRentalScreenState();
}

class _VanRentalScreenState extends State<VanRentalScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── Tab bar header ────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(
              AppConstants.defaultPadding,
              AppConstants.defaultPadding,
              AppConstants.defaultPadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Van Rental Management',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: AppConstants.smallPadding),
                TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: Theme.of(context).primaryColor,
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.directions_bus_outlined),
                      text: 'Rental Listings',
                      iconMargin: const EdgeInsets.only(bottom: 2),
                    ),
                    _RentalRequestsTabLabel(tabController: _tabController),
                  ],
                ),
              ],
            ),
          ),

          // ── Tab views ─────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _RentalListingsTab(),
                _RentalRequestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Tab label with pending badge
class _RentalRequestsTabLabel extends StatelessWidget {
  final TabController tabController;
  const _RentalRequestsTabLabel({required this.tabController});

  @override
  Widget build(BuildContext context) {
    return Consumer<VanRentalRequestProvider>(
      builder: (_, provider, __) {
        final pending = provider.pendingRequests.length;
        return Tab(
          iconMargin: const EdgeInsets.only(bottom: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_long_outlined, size: 20),
              const SizedBox(width: 6),
              const Text('Rental Requests'),
              if (pending > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$pending',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 1 — Rental Listings  (admin manages vans available for rent)
// ═════════════════════════════════════════════════════════════════════════════

class _RentalListingsTab extends StatefulWidget {
  const _RentalListingsTab();

  @override
  State<_RentalListingsTab> createState() => _RentalListingsTabState();
}

class _RentalListingsTabState extends State<_RentalListingsTab> {
  String _search = '';
  final _searchCtrl = TextEditingController();
  String _availFilter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: AppConstants.defaultPadding),
          _buildFilters(),
          const SizedBox(height: AppConstants.defaultPadding),
          Expanded(child: _buildGrid(context)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Consumer<RentalVanListingProvider>(
            builder: (_, p, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p.listings.length} listed · ${p.availableListings.length} available for rent',
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 2),
                const Text(
                  'These vans will appear on the user app as available for rental.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.add),
          label: const Text('Add Rental'),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Search by plate, brand, driver, location…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
          ),
        ),
        const SizedBox(width: AppConstants.defaultPadding),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _availFilter,
            isDense: true,
            decoration:
                const InputDecoration(labelText: 'Status', isDense: true),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All')),
              DropdownMenuItem(
                  value: 'available', child: Text('Available')),
              DropdownMenuItem(
                  value: 'unavailable', child: Text('Unavailable')),
            ],
            onChanged: (v) =>
                setState(() => _availFilter = v ?? 'all'),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(BuildContext context) {
    return Consumer<RentalVanListingProvider>(
      builder: (_, provider, __) {
        if (provider.isLoading && provider.listings.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        var items = provider.listings;

        if (_availFilter == 'available') {
          items = items.where((l) => l.isAvailable).toList();
        } else if (_availFilter == 'unavailable') {
          items = items.where((l) => !l.isAvailable).toList();
        }

        if (_search.isNotEmpty) {
          items = items.where((l) =>
              l.plateNumber.toLowerCase().contains(_search) ||
              l.brand.toLowerCase().contains(_search) ||
              l.driverName.toLowerCase().contains(_search) ||
              l.pickupLocation.toLowerCase().contains(_search)).toList();
        }

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.car_rental, size: 72, color: Colors.grey[300]),
                const SizedBox(height: AppConstants.defaultPadding),
                Text(
                  provider.listings.isEmpty
                      ? 'No rental van listings yet.\nTap "Add Rental Van" to get started.'
                      : 'No listings match your filters.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 15),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(builder: (ctx, constraints) {
          final crossCount = constraints.maxWidth > 900
              ? 3
              : constraints.maxWidth > 600
                  ? 2
                  : 1;
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossCount,
              crossAxisSpacing: AppConstants.defaultPadding,
              mainAxisSpacing: AppConstants.defaultPadding,
              childAspectRatio: 1.35,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => _ListingCard(
              listing: items[i],
              onEdit: () => _openForm(context, listing: items[i]),
            ),
          );
        });
      },
    );
  }

  void _openForm(BuildContext context, {RentalVanListing? listing}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(
            horizontal: AppConstants.largePadding,
            vertical: AppConstants.largePadding),
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppConstants.defaultBorderRadius)),
        child: _ListingFormDialog(
          existing: listing,
          onSave: (l) async {
            final p = context.read<RentalVanListingProvider>();
            if (listing == null) {
              await p.createListing(l);
            } else {
              await p.updateListing(listing.id, l);
            }
          },
        ),
      ),
    );
  }
}

// ── Listing card ──────────────────────────────────────────────────────────────

class _ListingCard extends StatelessWidget {
  final RentalVanListing listing;
  final VoidCallback onEdit;

  const _ListingCard({required this.listing, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '₱', decimalDigits: 0);
    final provider = context.read<RentalVanListingProvider>();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top: plate + type badge + toggle ─────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    listing.plateNumber,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                        fontSize: 13),
                  ),
                ),
                const SizedBox(width: 6),
                _badge(listing.vehicleType.toUpperCase(),
                    Colors.blueGrey[700]!),
                const SizedBox(width: 6),
                _badge(
                  listing.isAvailable ? 'AVAILABLE' : 'RENTED',
                  listing.isAvailable ? Colors.green[700]! : Colors.red[700]!,
                ),
                const Spacer(),
                Tooltip(
                  message: listing.isAvailable
                      ? 'Visible to users'
                      : 'Hidden from users',
                  child: Switch.adaptive(
                    value: listing.isAvailable,
                    onChanged: (v) =>
                        provider.toggleAvailability(listing.id, v),
                    activeColor: Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // ── Brand / color ─────────────────────────────────────────────
            if (listing.brand.isNotEmpty)
              Text(
                listing.brand +
                    (listing.color.isNotEmpty
                        ? '  ·  ${listing.color}'
                        : ''),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),

            // ── Price ─────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmt.format(listing.pricePerDay),
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3, left: 3),
                  child: Text(' / day',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[600])),
                ),
              ],
            ),

            // ── Driver + capacity ─────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    '${listing.driverName}  ·  ${listing.capacity} seats',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // ── Pickup location ───────────────────────────────────────────
            if (listing.pickupLocation.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 13, color: Colors.grey),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      listing.pickupLocation,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

            // ── Min days ─────────────────────────────────────────────────
            Text(
              'Min: ${listing.minRentalDays} day(s)'
              '${listing.maxRentalDays > 0 ? '  ·  Max: ${listing.maxRentalDays} day(s)' : ''}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),

            const SizedBox(height: 6),

            // ── Amenity chips ─────────────────────────────────────────────
            if (listing.amenities.isNotEmpty)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  ...listing.amenities.take(3).map((a) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(a,
                            style: const TextStyle(fontSize: 10)),
                      )),
                  if (listing.amenities.length > 3)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                          '+${listing.amenities.length - 3} more',
                          style: const TextStyle(fontSize: 10)),
                    ),
                ],
              ),

            const Spacer(),

            // ── Actions ───────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 15),
                  label: const Text('Edit',
                      style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8)),
                ),
                TextButton.icon(
                  onPressed: () =>
                      _confirmDelete(context, listing, provider),
                  icon: const Icon(Icons.delete_outline, size: 15),
                  label: const Text('Remove',
                      style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.red[600],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, RentalVanListing listing,
      RentalVanListingProvider provider) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Remove Listing'),
        content: Text(
            'Remove "${listing.plateNumber}" from rental listings?\n\nThis will hide it from the user app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dialogCtx);
              provider.deleteListing(listing.id);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ── Listing form dialog ───────────────────────────────────────────────────────

class _ListingFormDialog extends StatefulWidget {
  final RentalVanListing? existing;
  final Future<void> Function(RentalVanListing) onSave;

  const _ListingFormDialog({this.existing, required this.onSave});

  @override
  State<_ListingFormDialog> createState() => _ListingFormDialogState();
}

class _ListingFormDialogState extends State<_ListingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  Van? _selectedVan;
  final _plateCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _minDaysCtrl = TextEditingController(text: '1');
  final _maxDaysCtrl = TextEditingController(text: '0');
  final _pickupCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _imgCtrl = TextEditingController();

  List<String> _amenities = [];
  List<String> _imageUrls = [];
  bool _isAvailable = true;
  DateTime? _availFrom;
  DateTime? _availTo;
  String _vehicleType = 'van';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _plateCtrl.text = e.plateNumber;
      _brandCtrl.text = e.brand;
      _colorCtrl.text = e.color;
      _priceCtrl.text = e.pricePerDay.toStringAsFixed(2);
      _minDaysCtrl.text = e.minRentalDays.toString();
      _maxDaysCtrl.text = e.maxRentalDays.toString();
      _pickupCtrl.text = e.pickupLocation;
      _descCtrl.text = e.description;
      _notesCtrl.text = e.adminNotes;
      _amenities = List.from(e.amenities);
      _imageUrls = List.from(e.imageUrls);
      _isAvailable = e.isAvailable;
      _availFrom = e.availableFrom;
      _availTo = e.availableTo;
      _vehicleType = e.vehicleType;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _plateCtrl, _brandCtrl, _colorCtrl, _priceCtrl, _minDaysCtrl,
      _maxDaysCtrl, _pickupCtrl, _descCtrl, _notesCtrl, _imgCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 720,
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.car_rental, color: Colors.white),
                const SizedBox(width: AppConstants.smallPadding),
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Rental Van' : 'Add Van for Rental',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white)),
              ],
            ),
          ),

          // Form body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sec('Van Details'),
                    _buildVanSelector(context),
                    const SizedBox(height: AppConstants.smallPadding),
                    _buildVehicleTypeSelector(),
                    const SizedBox(height: AppConstants.smallPadding),
                    _tf(
                      _plateCtrl,
                      'Plate Number *',
                      hint: 'e.g. ABC 1234',
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9 ]')),
                        TextInputFormatter.withFunction(
                          (old, newVal) => newVal.copyWith(
                            text: newVal.text.toUpperCase()),
                        ),
                      ],
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: AppConstants.smallPadding),
                    Row(children: [
                      Expanded(
                          child: _tf(_brandCtrl, 'Brand / Model',
                              hint: 'e.g. Toyota HiAce')),
                      const SizedBox(width: AppConstants.defaultPadding),
                      Expanded(
                          child: _tf(_colorCtrl, 'Color',
                              hint: 'e.g. Pearl White')),
                    ]),

                    const SizedBox(height: AppConstants.defaultPadding),
                    _sec('Pricing & Rental Duration'),
                    Row(children: [
                      Expanded(
                        flex: 2,
                        child: _tf(
                          _priceCtrl,
                          'Price Per Day (₱) *',
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}'))
                          ],
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                        ),
                      ),
                      const SizedBox(width: AppConstants.defaultPadding),
                      Expanded(
                          child: _tf(_minDaysCtrl, 'Min Days',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ])),
                      const SizedBox(width: AppConstants.defaultPadding),
                      Expanded(
                          child: _tf(_maxDaysCtrl, 'Max Days (0=∞)',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ])),
                    ]),

                    const SizedBox(height: AppConstants.defaultPadding),
                    _sec('Availability'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: _datePicker(
                          label: 'Available From (optional)',
                          value: _availFrom,
                          onPick: (d) => setState(() => _availFrom = d),
                          onClear: () => setState(() => _availFrom = null),
                        )),
                        const SizedBox(width: AppConstants.defaultPadding),
                        Expanded(child: _datePicker(
                          label: 'Available Until (optional)',
                          value: _availTo,
                          onPick: (d) => setState(() => _availTo = d),
                          onClear: () => setState(() => _availTo = null),
                          firstDate: _availFrom,
                        )),
                        const SizedBox(width: AppConstants.defaultPadding),
                        Column(
                          children: [
                            const Text('Show to Users',
                                style: TextStyle(fontSize: 12)),
                            Switch.adaptive(
                              value: _isAvailable,
                              onChanged: (v) =>
                                  setState(() => _isAvailable = v),
                              activeColor: Colors.green,
                            ),
                          ],
                        )
                      ],
                    ),

                    const SizedBox(height: AppConstants.defaultPadding),
                    _sec('Location & Description'),
                    _tf(_pickupCtrl, 'Default Pickup Location',
                        prefixIcon: Icons.location_on),
                    const SizedBox(height: AppConstants.smallPadding),
                    _tf(_descCtrl,
                        'Description (visible to users on the app)',
                        maxLines: 3),

                    const SizedBox(height: AppConstants.defaultPadding),
                    _sec('Amenities'),
                    Wrap(
                      spacing: AppConstants.smallPadding,
                      runSpacing: AppConstants.smallPadding,
                      children: RentalVanListing.amenityPresets
                          .map((a) {
                        final on = _amenities.contains(a);
                        return FilterChip(
                          label: Text(a,
                              style: const TextStyle(fontSize: 12)),
                          selected: on,
                          onSelected: (v) => setState(() {
                            v ? _amenities.add(a) : _amenities.remove(a);
                          }),
                          selectedColor: Theme.of(context)
                              .primaryColor
                              .withOpacity(0.15),
                          checkmarkColor:
                              Theme.of(context).primaryColor,
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: AppConstants.defaultPadding),
                    _sec('Photo URLs'),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _imgCtrl,
                          decoration: const InputDecoration(
                              hintText: 'https://…',
                              prefixIcon: Icon(Icons.image_outlined),
                              isDense: true),
                        ),
                      ),
                      const SizedBox(width: AppConstants.smallPadding),
                      IconButton(
                        tooltip: 'Add URL',
                        icon:
                            const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          final url = _imgCtrl.text.trim();
                          if (url.isNotEmpty &&
                              !_imageUrls.contains(url)) {
                            setState(() {
                              _imageUrls.add(url);
                              _imgCtrl.clear();
                            });
                          }
                        },
                      ),
                    ]),
                    if (_imageUrls.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                            top: AppConstants.smallPadding),
                        child: Wrap(
                          spacing: AppConstants.smallPadding,
                          runSpacing: AppConstants.smallPadding,
                          children: _imageUrls
                              .map((u) => Chip(
                                    label: Text(
                                      u.length > 38
                                          ? '…${u.substring(u.length - 36)}'
                                          : u,
                                      style: const TextStyle(
                                          fontSize: 11),
                                    ),
                                    deleteIcon: const Icon(
                                        Icons.close,
                                        size: 14),
                                    onDeleted: () => setState(
                                        () => _imageUrls.remove(u)),
                                  ))
                              .toList(),
                        ),
                      ),

                    const SizedBox(height: AppConstants.defaultPadding),
                    _sec('Admin Notes (internal only)'),
                    _tf(_notesCtrl, 'Notes', maxLines: 2),
                  ],
                ),
              ),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                const SizedBox(width: AppConstants.smallPadding),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(
                      isEdit ? 'Update Listing' : 'Add Rental'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVanSelector(BuildContext context) {
    return Consumer<VanProvider>(
      builder: (_, vp, __) {
        final vans = vp.vans;
        return DropdownButtonFormField<Van>(
          value: _selectedVan,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Link to existing van (optional)',
            prefixIcon: Icon(Icons.directions_bus),
            helperText:
                'Selecting a van auto-fills plate, driver & capacity',
          ),
          hint: const Text('Choose a van to pre-fill details'),
          items: vans
              .map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(
                        '${v.plateNumber} — ${v.driver.name} (cap: ${v.capacity})'),
                  ))
              .toList(),
          onChanged: (v) => setState(() {
            _selectedVan = v;
            if (v != null) {
              _plateCtrl.text = v.plateNumber;
              if (_brandCtrl.text.isEmpty) _brandCtrl.text = v.vehicleType;
              _vehicleType = v.vehicleType;
            }
          }),
        );
      },
    );
  }

  Widget _buildVehicleTypeSelector() {
    return DropdownButtonFormField<String>(
      value: _vehicleType,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Vehicle Type *',
        prefixIcon: Icon(Icons.directions_bus),
      ),
      items: const [
        DropdownMenuItem(
          value: 'van',
          child: Text('Van'),
        ),
        DropdownMenuItem(
          value: 'bus',
          child: Text('Bus'),
        ),
      ],
      onChanged: (v) => setState(() {
        _vehicleType = v ?? 'van';
      }),
    );
  }

  Widget _sec(String title) => Padding(
        padding:
            const EdgeInsets.only(bottom: AppConstants.smallPadding),
        child: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Theme.of(context).primaryColor)),
      );

  Widget _tf(
    TextEditingController ctrl,
    String label, {
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    IconData? prefixIcon,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon:
            prefixIcon != null ? Icon(prefixIcon) : null,
      ),
      validator: validator,
    );
  }

  Widget _datePicker({
    required String label,
    required DateTime? value,
    required void Function(DateTime) onPick,
    required VoidCallback onClear,
    DateTime? firstDate,
  }) {
    final df = DateFormat('MMM dd, yyyy');
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: firstDate ?? DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPick(picked);
      },
      child: AbsorbPointer(
        child: TextFormField(
          readOnly: true,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today),
            suffixIcon: value != null
                ? GestureDetector(
                    onTap: onClear,
                    child: const Icon(Icons.clear, size: 18),
                  )
                : null,
          ),
          controller: TextEditingController(
              text: value != null ? df.format(value) : ''),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final e = widget.existing;
    final van = _selectedVan;

    final listing = RentalVanListing(
      id: e?.id ?? '',
      vanId: van?.id ?? e?.vanId ?? '',
      plateNumber: _plateCtrl.text.trim().toUpperCase().isNotEmpty
          ? _plateCtrl.text.trim().toUpperCase()
          : van?.plateNumber ?? e?.plateNumber ?? '',
      vehicleType: _vehicleType,
      capacity: van?.capacity ?? e?.capacity ?? 0,
      brand: _brandCtrl.text.trim(),
      color: _colorCtrl.text.trim(),
      driverName: van?.driver.name ?? e?.driverName ?? '',
      driverContact: van?.driver.contact ?? e?.driverContact ?? '',
      driverLicense: van?.driver.license ?? e?.driverLicense ?? '',
      pricePerDay: double.tryParse(_priceCtrl.text) ?? 0,
      minRentalDays: int.tryParse(_minDaysCtrl.text) ?? 1,
      maxRentalDays: int.tryParse(_maxDaysCtrl.text) ?? 0,
      description: _descCtrl.text.trim(),
      amenities: List.from(_amenities),
      imageUrls: List.from(_imageUrls),
      pickupLocation: _pickupCtrl.text.trim(),
      isAvailable: _isAvailable,
      availableFrom: _availFrom,
      availableTo: _availTo,
      blockedDates: e?.blockedDates ?? [],
      createdAt: e?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      adminNotes: _notesCtrl.text.trim(),
    );

    try {
      await widget.onSave(listing);
      if (mounted) Navigator.pop(context);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $err'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 2 — Rental Requests  (user-submitted booking requests)
// ═════════════════════════════════════════════════════════════════════════════

class _RentalRequestsTab extends StatefulWidget {
  const _RentalRequestsTab();

  @override
  State<_RentalRequestsTab> createState() => _RentalRequestsTabState();
}

class _RentalRequestsTabState extends State<_RentalRequestsTab> {
  String _statusFilter = 'all';
  String _search = '';
  final _searchCtrl = TextEditingController();

  final List<String> _statuses = [
    'all', 'pending', 'approved', 'rejected', 'completed', 'cancelled'
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        children: [
          _buildFilters(),
          const SizedBox(height: AppConstants.defaultPadding),
          Expanded(child: _buildList(context)),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Search by renter name, plate, email…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) =>
                setState(() => _search = v.toLowerCase()),
          ),
        ),
        const SizedBox(width: AppConstants.defaultPadding),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _statusFilter,
            isDense: true,
            decoration:
                const InputDecoration(labelText: 'Status', isDense: true),
            items: _statuses
                .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s == 'all'
                        ? 'All Statuses'
                        : s[0].toUpperCase() + s.substring(1))))
                .toList(),
            onChanged: (v) =>
                setState(() => _statusFilter = v ?? 'all'),
          ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    return Consumer<VanRentalRequestProvider>(
      builder: (_, provider, __) {
        if (provider.isLoading && provider.requests.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        var items = provider.requests;

        if (_statusFilter != 'all') {
          items = items
              .where((r) => r.status == _statusFilter)
              .toList();
        }

        if (_search.isNotEmpty) {
          items = items.where((r) {
            return r.brand.toLowerCase().contains(_search) ||
                r.pickupLocation.toLowerCase().contains(_search) ||
                r.purpose.toLowerCase().contains(_search);
          }).toList();
        }

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long,
                    size: 72, color: Colors.grey[300]),
                const SizedBox(height: AppConstants.defaultPadding),
                Text(
                  provider.requests.isEmpty
                      ? 'No rental requests yet.\nRental requests from users will appear here.'
                      : 'No requests match your filters.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 15),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: AppConstants.smallPadding),
          itemBuilder: (_, i) =>
              _RequestCard(request: items[i], provider: provider),
        );
      },
    );
  }
}

// ── Rental request card ───────────────────────────────────────────────────────

class _RequestCard extends StatefulWidget {
  final VanRentalRequest request;
  final VanRentalRequestProvider provider;

  const _RequestCard({required this.request, required this.provider});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _isActing = false;

  VanRentalRequest get request => widget.request;
  VanRentalRequestProvider get provider => widget.provider;

  Future<void> _doAction(Future<bool> Function() action, String successMsg) async {
    setState(() => _isActing = true);
    try {
      final ok = await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? successMsg : 'Error: ${provider.errorMessage ?? 'Unknown error'}'),
          backgroundColor: ok ? Colors.green[700] : Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM dd, yyyy');
    final fmt = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(AppConstants.defaultBorderRadius),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row: brand + status badge ─────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        Theme.of(context).primaryColor.withOpacity(0.12),
                    child: const Icon(Icons.directions_bus, size: 20),
                  ),
                  const SizedBox(width: AppConstants.smallPadding),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.brand.isNotEmpty
                              ? request.brand
                              : 'Van Rental Request',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          'Purpose: ${request.purpose.isNotEmpty ? request.purpose : '—'}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(request.status),
                ],
              ),

              const Divider(height: AppConstants.largePadding),

              // ── Details row ──────────────────────────────────────────
              Wrap(
                spacing: AppConstants.largePadding,
                runSpacing: 4,
                children: [
                  _chip(Icons.location_on_outlined, request.pickupLocation),
                  _chip(Icons.person,
                      request.dropoffLocation),
                  _chip(Icons.calendar_today,
                      '${df.format(request.rentalStartDate)} → ${df.format(request.rentalEndDate)}'),
                  _chip(Icons.timer, '${request.totalDays} day(s)'),
                  _chip(Icons.payments,
                      '${fmt.format(request.pricePerDay)}/day'),
                ],
              ),

              const SizedBox(height: AppConstants.smallPadding),

              // ── Total + action buttons ────────────────────────────────
              Row(
                children: [
                  Text(
                    fmt.format(request.totalAmount),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).primaryColor),
                  ),
                  const Spacer(),
                  // Approve button — shown only for pending requests
                  if (request.status == 'pending')
                    ElevatedButton.icon(
                      onPressed: _isActing
                          ? null
                          : () => _doAction(
                                () => provider.approveRequest(request.id),
                                'Request approved successfully!',
                              ),
                      icon: _isActing
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline, size: 16),
                      label: Text(_isActing ? 'Processing…' : 'Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  if (request.status == 'approved')
                    _actionBtn(Icons.done_all, Colors.blueGrey,
                        'Mark Complete',
                        () => _doAction(
                              () => provider.completeRequest(request.id),
                              'Marked as completed!',
                            )),
                  if (request.status != 'cancelled' &&
                      request.status != 'completed' &&
                      request.status != 'rejected') ...[
                    const SizedBox(width: 6),
                    _actionBtn(Icons.cancel_outlined, Colors.red,
                        'Reject / Cancel',
                        () => _rejectDialog(context)),
                  ],
                  // Manual status updater (always visible)
                  const SizedBox(width: 6),
                  _actionBtn(Icons.edit_note, Colors.blueGrey,
                      'Update Status',
                      () => _updateStatusDialog(context)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _rejectDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Reject / Cancel Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Confirm rejection of this rental request?'),
            const SizedBox(height: AppConstants.defaultPadding),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                  labelText: 'Reason (optional)'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Back')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final reason = ctrl.text.trim();
              Navigator.pop(dialogCtx);
              _doAction(
                () => provider.rejectRequest(request.id, reason: reason),
                'Request rejected.',
              );
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _updateStatusDialog(BuildContext context) {
    String? selected = request.status;
    const statuses = ['pending', 'approved', 'rejected', 'completed', 'cancelled'];
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDs) => AlertDialog(
          title: const Text('Update Request Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: statuses.map((s) {
              final color = Color(VanRentalRequest.statusColors[s] ?? 0xFF9E9E9E);
              return RadioListTile<String>(
                value: s,
                groupValue: selected,
                onChanged: (v) => setDs(() => selected = v),
                title: Text(
                  s[0].toUpperCase() + s.substring(1),
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
                activeColor: color,
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }).toList(),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selected == null || selected == request.status
                  ? null
                  : () {
                      final newStatus = selected!;
                      Navigator.pop(dialogCtx);
                      _doAction(() async {
                        switch (newStatus) {
                          case 'approved':
                            return provider.approveRequest(request.id);
                          case 'completed':
                            return provider.completeRequest(request.id);
                          case 'rejected':
                          case 'cancelled':
                            return provider.rejectRequest(request.id);
                          default:
                            return false;
                        }
                      }, 'Status updated to "$newStatus"');
                    },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final df = DateFormat('MMM dd, yyyy');
    final dtf = DateFormat('MMM dd, yyyy HH:mm');
    final fmt = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, sc) => Consumer<VanRentalRequestProvider>(
          builder: (_, liveProvider, __) {
            // use live request from provider; fall back to captured request
            final liveReq = liveProvider.requests
                .firstWhere((r) => r.id == request.id,
                    orElse: () => request);
            return ListView(
              controller: sc,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.defaultPadding),
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        vertical: AppConstants.smallPadding),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(children: [
                  Expanded(
                    child: Text('Rental Request Detail',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      icon: const Icon(Icons.close)),
                ]),
                _statusBadge(liveReq.status),
                const Divider(height: AppConstants.largePadding),
                _dtRow(context, 'Payment',
                    liveReq.paymentStatus == 'paid' ? '✅ Paid' : '⏳ Pending'),
                _dtRow(context, 'Brand / Model',
                    liveReq.brand.isNotEmpty ? liveReq.brand : '—'),
                _dtRow(context, 'Pickup', liveReq.pickupLocation),
                _dtRow(context, 'Name', liveReq.dropoffLocation),
                _dtRow(context, 'Purpose', liveReq.purpose),
                if (liveReq.specialRequirements.isNotEmpty)
                  _dtRow(context, 'Special Req.',
                      liveReq.specialRequirements),
                const Divider(height: AppConstants.largePadding),
                _dtRow(context, 'Start Date',
                    df.format(liveReq.rentalStartDate)),
                _dtRow(context, 'End Date',
                    df.format(liveReq.rentalEndDate)),
                _dtRow(context, 'Duration', '${liveReq.totalDays} day(s)'),
                _dtRow(context, 'Price / Day',
                    fmt.format(liveReq.pricePerDay)),
                _dtRow(context, 'Total', fmt.format(liveReq.totalAmount),
                    highlight: true),
                const Divider(height: AppConstants.largePadding),
                _dtRow(context, 'Submitted On', dtf.format(liveReq.createdAt)),
                if (liveReq.confirmedAt != null)
                  _dtRow(context, 'Approved At',
                      dtf.format(liveReq.confirmedAt!)),
                if (liveReq.completedAt != null)
                  _dtRow(context, 'Completed At',
                      dtf.format(liveReq.completedAt!)),
                if (liveReq.cancelledAt != null)
                  _dtRow(context, 'Cancelled At',
                      dtf.format(liveReq.cancelledAt!)),
                if (liveReq.cancellationReason != null &&
                    liveReq.cancellationReason!.isNotEmpty)
                  _dtRow(context, 'Reason', liveReq.cancellationReason!),
                const SizedBox(height: AppConstants.largePadding * 2),
                // Action buttons in detail sheet
                Padding(
                  padding: const EdgeInsets.only(
                      bottom: AppConstants.defaultPadding),
                  child: Column(
                    children: [
                      if (liveReq.paymentStatus != 'paid')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isActing
                                ? null
                                : () {
                                    Navigator.pop(sheetCtx);
                                    _doAction(
                                      () => provider.markAsPaid(liveReq.id),
                                      'Marked as paid!',
                                    );
                                  },
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Mark as Paid'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      if (liveReq.status == 'pending') ...[
                        const SizedBox(height: AppConstants.smallPadding),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isActing
                                    ? null
                                    : () {
                                        Navigator.pop(sheetCtx);
                                        _doAction(
                                          () => provider.approveRequest(
                                              liveReq.id),
                                          'Request approved successfully!',
                                        );
                                      },
                                icon: const Icon(
                                    Icons.check_circle_outline),
                                label: const Text('Approve Request'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(
                                width: AppConstants.smallPadding),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(sheetCtx);
                                  _rejectDialog(context);
                                },
                                icon: const Icon(
                                    Icons.cancel_outlined,
                                    color: Colors.red),
                                label: const Text('Reject',
                                    style:
                                        TextStyle(color: Colors.red)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: Colors.red),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (liveReq.status == 'approved') ...[
                        const SizedBox(height: AppConstants.smallPadding),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isActing
                                ? null
                                : () {
                                    Navigator.pop(sheetCtx);
                                    _doAction(
                                      () => provider.completeRequest(
                                          liveReq.id),
                                      'Marked as completed!',
                                    );
                                  },
                            icon: const Icon(Icons.done_all),
                            label: const Text('Mark as Completed'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppConstants.smallPadding),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _updateStatusDialog(context);
                          },
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Update Status'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dtRow(BuildContext context, String label, String value,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: AppConstants.smallPadding / 2),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 140,
                child: Text(label,
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 13))),
            Expanded(
                child: Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: highlight
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color:
                            highlight ? const Color(0xFF4CAF50) : null))),
          ]),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: Colors.grey[600]),
      const SizedBox(width: 3),
      Text(label,
          style: TextStyle(fontSize: 12, color: Colors.grey[700])),
    ]);
  }

  Widget _actionBtn(
      IconData icon, Color color, String tip, Function() onTap) {
    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: _isActing ? null : () => onTap(),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 22, color: _isActing ? Colors.grey : color),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final cm = VanRentalRequest.statusColors;
    final color = Color(cm[status] ?? 0xFF9E9E9E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(status[0].toUpperCase() + status.substring(1),
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }

}
