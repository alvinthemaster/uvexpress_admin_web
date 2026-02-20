import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/rental_van_listing_model.dart';
import '../models/van_rental_model.dart';
import '../models/van_model.dart';
import '../providers/rental_van_listing_provider.dart';
import '../providers/van_rental_provider.dart';
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
    return Consumer<VanRentalProvider>(
      builder: (_, provider, __) {
        final pending = provider.pendingRentals.length;
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
          label: const Text('Add Rental Van'),
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
      builder: (_) => AlertDialog(
        title: const Text('Remove Listing'),
        content: Text(
            'Remove "${listing.plateNumber}" from rental listings?\n\nThis will hide it from the user app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
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

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
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
    }
  }

  @override
  void dispose() {
    for (final c in [
      _brandCtrl, _colorCtrl, _priceCtrl, _minDaysCtrl,
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
                      isEdit ? 'Update Listing' : 'Add to Rental'),
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
            if (v != null && _brandCtrl.text.isEmpty) {
              _brandCtrl.text = v.vehicleType;
            }
          }),
        );
      },
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
      plateNumber: van?.plateNumber ?? e?.plateNumber ?? '',
      vehicleType: van?.vehicleType ?? e?.vehicleType ?? 'van',
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
    'all', 'pending', 'confirmed', 'active', 'completed', 'cancelled'
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
    return Consumer<VanRentalProvider>(
      builder: (_, provider, __) {
        if (provider.isLoading && provider.rentals.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        var items = provider.rentals;

        if (_statusFilter != 'all') {
          items = items
              .where((r) => r.rentalStatus == _statusFilter)
              .toList();
        }

        if (_search.isNotEmpty) {
          items = items.where((r) {
            return r.userName.toLowerCase().contains(_search) ||
                r.userEmail.toLowerCase().contains(_search) ||
                r.vanPlateNumber.toLowerCase().contains(_search);
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
                  provider.rentals.isEmpty
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
              _RequestCard(rental: items[i], provider: provider),
        );
      },
    );
  }
}

// ── Rental request card ───────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final VanRental rental;
  final VanRentalProvider provider;

  const _RequestCard({required this.rental, required this.provider});

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
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        Theme.of(context).primaryColor.withOpacity(0.12),
                    child: Text(
                      rental.userName.isNotEmpty
                          ? rental.userName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: AppConstants.smallPadding),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rental.userName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        Text(rental.userEmail,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  _statusBadge(rental.rentalStatus),
                ],
              ),

              const Divider(height: AppConstants.largePadding),

              Wrap(
                spacing: AppConstants.largePadding,
                runSpacing: 4,
                children: [
                  _chip(Icons.directions_bus, rental.vanPlateNumber),
                  _chip(Icons.calendar_today,
                      '${df.format(rental.startDate)} → ${df.format(rental.endDate)}'),
                  _chip(Icons.timer, '${rental.numberOfDays} day(s)'),
                  _chip(Icons.attach_money,
                      '${fmt.format(rental.pricePerDay)}/day'),
                ],
              ),

              const SizedBox(height: AppConstants.smallPadding),

              Row(
                children: [
                  Text(
                    fmt.format(rental.totalAmount),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(width: AppConstants.smallPadding),
                  _paymentBadge(rental.paymentStatus),
                  const Spacer(),
                  if (rental.rentalStatus == 'pending')
                    _actionBtn(
                        Icons.check_circle_outline,
                        Colors.blue,
                        'Confirm',
                        () => provider.confirmRental(rental.id)),
                  if (rental.rentalStatus == 'confirmed')
                    _actionBtn(
                        Icons.play_arrow_outlined,
                        Colors.green,
                        'Activate',
                        () => provider.activateRental(rental.id)),
                  if (rental.rentalStatus == 'active')
                    _actionBtn(
                        Icons.done_all,
                        Colors.blueGrey,
                        'Complete',
                        () => provider.completeRental(rental.id)),
                  if (rental.rentalStatus != 'cancelled' &&
                      rental.rentalStatus != 'completed')
                    _actionBtn(Icons.cancel_outlined, Colors.red,
                        'Cancel', () => _cancelDialog(context)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _cancelDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Rental Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Confirm cancellation of this rental request?'),
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Back')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              provider.cancelRental(rental.id,
                  reason: ctrl.text.trim());
            },
            child: const Text('Cancel Rental'),
          ),
        ],
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
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.defaultPadding),
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(
                    vertical: AppConstants.smallPadding),
                width: 40, height: 4,
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
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
            Wrap(spacing: 8, children: [
              _statusBadge(rental.rentalStatus),
              _paymentBadge(rental.paymentStatus),
            ]),
            const Divider(height: AppConstants.largePadding),
            _dtRow(context, 'Renter', rental.userName),
            _dtRow(context, 'Email', rental.userEmail),
            _dtRow(context, 'Phone', rental.userPhone),
            const Divider(height: AppConstants.largePadding),
            _dtRow(context, 'Van Plate', rental.vanPlateNumber),
            _dtRow(context, 'Driver', rental.driverName),
            _dtRow(context, 'Driver Contact', rental.driverContact),
            const Divider(height: AppConstants.largePadding),
            _dtRow(context, 'Pickup', rental.pickupAddress),
            _dtRow(context, 'Dropoff', rental.dropoffAddress),
            _dtRow(context, 'Start Date', df.format(rental.startDate)),
            _dtRow(context, 'End Date', df.format(rental.endDate)),
            _dtRow(context, 'Duration', '${rental.numberOfDays} day(s)'),
            _dtRow(context, 'Passengers',
                '${rental.passengerCount} pax'),
            if (rental.purpose.isNotEmpty)
              _dtRow(context, 'Purpose', rental.purpose),
            if (rental.specialRequests.isNotEmpty)
              _dtRow(context, 'Requests', rental.specialRequests),
            const Divider(height: AppConstants.largePadding),
            _dtRow(context, 'Price / Day',
                fmt.format(rental.pricePerDay)),
            if (rental.additionalCharges > 0)
              _dtRow(context, 'Extra Charges',
                  fmt.format(rental.additionalCharges)),
            if (rental.discountAmount > 0)
              _dtRow(context, 'Discount',
                  '- ${fmt.format(rental.discountAmount)}'),
            _dtRow(context, 'Total', fmt.format(rental.totalAmount),
                highlight: true),
            const Divider(height: AppConstants.largePadding),
            _dtRow(context, 'Payment Method', rental.paymentMethod),
            _dtRow(context, 'Payment Status',
                rental.paymentStatus.toUpperCase()),
            if (rental.paymentReference != null)
              _dtRow(context, 'Reference',
                  rental.paymentReference!),
            const Divider(height: AppConstants.largePadding),
            _dtRow(context, 'Booked On',
                dtf.format(rental.bookingDate)),
            if (rental.confirmedAt != null)
              _dtRow(context, 'Confirmed At',
                  dtf.format(rental.confirmedAt!)),
            if (rental.activatedAt != null)
              _dtRow(context, 'Activated At',
                  dtf.format(rental.activatedAt!)),
            if (rental.completedAt != null)
              _dtRow(context, 'Completed At',
                  dtf.format(rental.completedAt!)),
            if (rental.cancelledAt != null)
              _dtRow(context, 'Cancelled At',
                  dtf.format(rental.cancelledAt!)),
            if (rental.cancellationReason != null &&
                rental.cancellationReason!.isNotEmpty)
              _dtRow(context, 'Cancel Reason',
                  rental.cancellationReason!),
            const SizedBox(height: AppConstants.largePadding * 2),
          ],
        ),
      ),
    );
  }

  Widget _dtRow(BuildContext context, String label, String value,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: AppConstants.smallPadding / 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 140,
            child: Text(label,
                style:
                    TextStyle(color: Colors.grey[600], fontSize: 13))),
        Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: highlight
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: highlight ? const Color(0xFF4CAF50) : null))),
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
      IconData icon, Color color, String tip, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    const cm = VanRental.statusColors;
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

  Widget _paymentBadge(String ps) {
    final Map<String, int> cm = {
      'pending': 0xFFF57C00,
      'paid': 0xFF4CAF50,
      'failed': 0xFFB00020,
      'refunded': 0xFF607D8B,
    };
    final color = Color(cm[ps] ?? 0xFF9E9E9E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10)),
      child: Text(ps[0].toUpperCase() + ps.substring(1),
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }
}
