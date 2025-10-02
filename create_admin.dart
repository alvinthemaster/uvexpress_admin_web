import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/firebase_options.dart';
import 'lib/models/admin_models.dart';

Future<void> main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('Creating admin account...');
  
  try {
    // Create the admin user in Firebase Auth
    UserCredential result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: 'admin@uvexpress.com',
      password: 'admin123',
    );

    if (result.user != null) {
      print('Firebase Auth user created successfully!');
      
      // Create admin user document in Firestore
      AdminUser adminUser = AdminUser(
        id: result.user!.uid,
        email: 'admin@uvexpress.com',
        name: 'Admin User',
        role: 'super_admin',
        permissions: [
          'all', // Super admin has all permissions
          'manage_users',
          'manage_bookings',
          'manage_vans',
          'manage_routes',
          'manage_discounts',
          'view_analytics',
          'export_data',
        ],
        isActive: true,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('admin_users')
          .doc(result.user!.uid)
          .set(adminUser.toFirestore());

      print('Admin user document created in Firestore!');
      print('✅ Admin account created successfully!');
      print('📧 Email: admin@uvexpress.com');
      print('🔐 Password: admin123');
      print('👤 Role: super_admin');
      print('🔑 Permissions: All permissions granted');
      
    } else {
      print('❌ Failed to create Firebase Auth user');
    }
  } catch (e) {
    if (e.toString().contains('email-already-in-use')) {
      print('⚠️  Admin user already exists with email: admin@uvexpress.com');
      print('You can use the existing credentials to login:');
      print('📧 Email: admin@uvexpress.com');
      print('🔐 Password: admin123');
    } else {
      print('❌ Error creating admin account: $e');
    }
  }
  
  print('\nScript completed. You can now close this and use the web app.');
}

//alvinthenoob