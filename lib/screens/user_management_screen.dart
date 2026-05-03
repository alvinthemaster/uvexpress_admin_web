import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/app_user_model.dart';
import '../providers/user_management_provider.dart';
import '../utils/constants.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _filterRole = 'all';
  String _filterStatus = 'all'; // all | active | restricted

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserManagementProvider>().startListening();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AppUser> _filtered(List<AppUser> all) {
    return all.where((u) {
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.phone.contains(q);
      final matchRole =
          _filterRole == 'all' || u.role == _filterRole;
      final matchStatus = _filterStatus == 'all' ||
          (_filterStatus == 'restricted' && u.isRestricted) ||
          (_filterStatus == 'active' && !u.isRestricted);
      return matchSearch && matchRole && matchStatus;
    }).toList();
  }

  // ── Dialogs ─────────────────────────────────────────────────────────

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (_) => const _UserFormDialog(),
    );
  }

  void _showEditDialog(AppUser user) {
    showDialog(
      context: context,
      builder: (_) => _UserFormDialog(user: user),
    );
  }

  void _showDeleteDialog(AppUser user) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
            'Are you sure you want to permanently delete "${user.name}"?\n\nThis will remove their Firestore record. Their authentication account will remain unless manually removed from Firebase Console.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await context
                    .read<UserManagementProvider>()
                    .deleteUser(user.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${user.name} has been deleted.'),
                    backgroundColor: Colors.red[700],
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRestrictDialog(AppUser user) {
    final isRestricting = !user.isRestricted;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(isRestricting ? 'Restrict User' : 'Unrestrict User'),
        content: Text(isRestricting
            ? 'Restricting "${user.name}" will prevent them from using the app. Continue?'
            : 'Unrestricting "${user.name}" will restore their access to the app. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: isRestricting ? Colors.orange[700] : Colors.green[700]),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                final provider = context.read<UserManagementProvider>();
                if (isRestricting) {
                  await provider.restrictUser(user.id);
                } else {
                  await provider.unrestrictUser(user.id);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isRestricting
                        ? '${user.name} has been restricted.'
                        : '${user.name} has been unrestricted.'),
                    backgroundColor:
                        isRestricting ? Colors.orange[700] : Colors.green[700],
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            },
            child: Text(isRestricting ? 'Restrict' : 'Unrestrict'),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<UserManagementProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                  const SizedBox(height: 12),
                  Text('Failed to load users',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(provider.errorMessage!,
                      style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => provider.startListening(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final filtered = _filtered(provider.users);

          return Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: AppConstants.defaultPadding),
                _buildStats(provider),
                const SizedBox(height: AppConstants.defaultPadding),
                _buildSearchAndFilter(),
                const SizedBox(height: AppConstants.defaultPadding),
                Expanded(child: _buildTable(filtered)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'User Management',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _showAddUserDialog,
          icon: const Icon(Icons.person_add),
          label: const Text('Add User'),
        ),
      ],
    );
  }

  Widget _buildStats(UserManagementProvider provider) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Users',
            value: provider.totalCount,
            icon: Icons.people,
            color: Colors.blue[700]!,
          ),
        ),
        const SizedBox(width: AppConstants.defaultPadding),
        Expanded(
          child: _StatCard(
            label: 'Active',
            value: provider.activeCount,
            icon: Icons.check_circle,
            color: Colors.green[700]!,
          ),
        ),
        const SizedBox(width: AppConstants.defaultPadding),
        Expanded(
          child: _StatCard(
            label: 'Restricted',
            value: provider.restrictedCount,
            icon: Icons.block,
            color: Colors.orange[700]!,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Search by name, email or phone...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        const SizedBox(width: AppConstants.defaultPadding),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _filterRole,
            decoration: const InputDecoration(
              labelText: 'Role',
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Roles')),
              DropdownMenuItem(value: 'passenger', child: Text('Passenger')),
              DropdownMenuItem(value: 'conductor', child: Text('Conductor')),
              DropdownMenuItem(value: 'driver', child: Text('Driver')),
            ],
            onChanged: (v) => setState(() => _filterRole = v ?? 'all'),
          ),
        ),
        const SizedBox(width: AppConstants.defaultPadding),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _filterStatus,
            decoration: const InputDecoration(
              labelText: 'Status',
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Status')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(
                  value: 'restricted', child: Text('Restricted')),
            ],
            onChanged: (v) => setState(() => _filterStatus = v ?? 'all'),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<AppUser> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty || _filterRole != 'all' || _filterStatus != 'all'
                  ? 'No users match the current filters.'
                  : 'No users found.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final df = DateFormat('MMM dd, yyyy');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(Colors.grey[100]),
              headingRowHeight: 44,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 64,
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('User', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Joined', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Last Login', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: users.map((user) {
                final roleColor = Color(AppUser.roleColors[user.role] ?? 0xFF9E9E9E);
                return DataRow(cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: roleColor.withOpacity(0.15),
                          child: Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                            style: TextStyle(
                                color: roleColor, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(user.name.isNotEmpty ? user.name : '—',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  DataCell(Text(user.email.isNotEmpty ? user.email : '—')),
                  DataCell(Text(user.phone.isNotEmpty ? user.phone : '—')),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: roleColor.withOpacity(0.35)),
                      ),
                      child: Text(
                        user.displayRole,
                        style: TextStyle(
                            color: roleColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 11),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: user.isRestricted
                            ? Colors.orange[50]
                            : Colors.green[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: user.isRestricted
                                ? Colors.orange[200]!
                                : Colors.green[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            user.isRestricted ? Icons.block : Icons.check_circle,
                            size: 12,
                            color: user.isRestricted
                                ? Colors.orange[700]
                                : Colors.green[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user.isRestricted ? 'Restricted' : 'Active',
                            style: TextStyle(
                                color: user.isRestricted
                                    ? Colors.orange[700]
                                    : Colors.green[700],
                                fontWeight: FontWeight.w600,
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(Text(df.format(user.createdAt))),
                  DataCell(Text(
                    user.lastLogin != null ? df.format(user.lastLogin!) : '—',
                    style: TextStyle(color: Colors.grey[600]),
                  )),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: 'Edit',
                          child: IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: Colors.blue[600],
                            onPressed: () => _showEditDialog(user),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: user.isRestricted ? 'Unrestrict' : 'Restrict',
                          child: IconButton(
                            icon: Icon(
                              user.isRestricted ? Icons.lock_open : Icons.block,
                              size: 18,
                            ),
                            color: user.isRestricted
                                ? Colors.green[600]
                                : Colors.orange[600],
                            onPressed: () => _showRestrictDialog(user),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Delete',
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: Colors.red[600],
                            onPressed: () => _showDeleteDialog(user),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value.toString(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── User Form Dialog (Add / Edit) ─────────────────────────────────────────────

class _UserFormDialog extends StatefulWidget {
  final AppUser? user;
  const _UserFormDialog({this.user});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _passwordCtrl;
  late String _role;
  bool _isLoading = false;
  bool _obscurePassword = true;

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user?.name ?? '');
    _emailCtrl = TextEditingController(text: widget.user?.email ?? '');
    _phoneCtrl = TextEditingController(text: widget.user?.phone ?? '');
    _passwordCtrl = TextEditingController();
    _role = widget.user?.role ?? 'passenger';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final provider = context.read<UserManagementProvider>();
      if (_isEditing) {
        await provider.updateUser(
          uid: widget.user!.id,
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          role: _role,
        );
      } else {
        await provider.createUser(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          role: _role,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing
              ? 'User updated successfully.'
              : 'User created successfully. A verification email has been sent to ${_emailCtrl.text.trim()}.'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit User' : 'Add New User'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              if (!_isEditing) ...[
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'At least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(
                  labelText: 'Role *',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'passenger', child: Text('Passenger')),
                  DropdownMenuItem(value: 'conductor', child: Text('Conductor')),
                  DropdownMenuItem(value: 'driver', child: Text('Driver')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'passenger'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEditing ? 'Save Changes' : 'Create User'),
        ),
      ],
    );
  }
}
