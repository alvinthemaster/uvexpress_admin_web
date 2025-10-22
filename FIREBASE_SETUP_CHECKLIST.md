# Firebase Setup Checklist for Godtrasco Admin

## ✅ Current Status

### COMPLETED
- ✅ Firebase configuration updated in `firebase_options.dart`
- ✅ Admin email updated to `admin@godtrasco.com`
- ✅ Flutter app running successfully
- ✅ Firebase SDK initialized

### REQUIRED - Complete These Steps

---

## Step 1: Enable Authentication

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **e-ticket-ff181**
3. Click **Authentication** in the left sidebar
4. Click **Get Started** (if not already enabled)
5. Go to **Sign-in method** tab
6. Enable **Email/Password**:
   - Click on "Email/Password"
   - Toggle **Enable** ON
   - Click **Save**
7. (Optional) Add your domain to **Authorized domains** for web deployment

---

## Step 2: Create Firestore Database

1. In Firebase Console, click **Firestore Database** in the left sidebar
2. Click **Create database**
3. Choose **Production mode** (we'll set custom rules next)
4. Select a location: **asia-southeast1** (Singapore) or closest to your region
5. Click **Enable**

---

## Step 3: Set Firestore Security Rules

1. In Firestore Database, go to the **Rules** tab
2. **Replace** the existing rules with the following:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isAdmin() {
      return isAuthenticated() && 
             exists(/databases/$(database)/documents/admin_users/$(request.auth.uid)) &&
             get(/databases/$(database)/documents/admin_users/$(request.auth.uid)).data.isActive == true;
    }
    
    function isSuperAdmin() {
      return isAdmin() && 
             get(/databases/$(database)/documents/admin_users/$(request.auth.uid)).data.role == 'super_admin';
    }
    
    // Admin users collection - only super admins can manage
    match /admin_users/{userId} {
      allow read: if isAdmin();
      allow create, update, delete: if isSuperAdmin();
    }
    
    // Vans collection
    match /vans/{vanId} {
      allow read: if isAdmin();
      allow create, update, delete: if isAdmin();
    }
    
    // Routes collection
    match /routes/{routeId} {
      allow read: if isAdmin();
      allow create, update, delete: if isAdmin();
    }
    
    // Bookings collection
    match /bookings/{bookingId} {
      allow read: if isAdmin();
      allow create, update, delete: if isAdmin();
    }
    
    // Discounts collection
    match /discounts/{discountId} {
      allow read: if isAdmin();
      allow create, update, delete: if isAdmin();
    }
    
    // Schedules collection
    match /schedules/{scheduleId} {
      allow read: if isAdmin();
      allow create, update, delete: if isAdmin();
    }
  }
}
```

3. Click **Publish**

---

## Step 4: Create Composite Indexes

Firestore will prompt you to create indexes when you first run queries that need them. However, you can create them in advance:

### Required Indexes:

1. **Bookings by Route and Date**
   - Collection: `bookings`
   - Fields: 
     - `routeId` (Ascending)
     - `travelDate` (Descending)
   - Query scope: Collection

2. **Bookings by Status and Date**
   - Collection: `bookings`
   - Fields:
     - `status` (Ascending)
     - `createdAt` (Descending)
   - Query scope: Collection

3. **Vans by Status and Queue Position**
   - Collection: `vans`
   - Fields:
     - `status` (Ascending)
     - `queuePosition` (Ascending)
   - Query scope: Collection

### How to Create Indexes:

1. In Firebase Console, go to **Firestore Database**
2. Click the **Indexes** tab
3. Click **Create Index**
4. Enter the collection and fields as specified above
5. Click **Create**

**OR** wait for the app to request them automatically when you run queries.

---

## Step 5: Create Admin Account

You have **TWO OPTIONS**:

### Option A: Using the App (Easiest)

1. Open your running app in Chrome
2. On the login screen, look for **"Development Only"** section
3. Click **"Create Admin Account"** button
4. You should see a success dialog with:
   - Email: `admin@godtrasco.com`
   - Password: `admin123`

### Option B: Manual Creation via Firebase Console

1. Go to **Authentication** → **Users** tab
2. Click **Add user**
3. Enter:
   - Email: `admin@godtrasco.com`
   - Password: `admin123`
4. Click **Add user**
5. Copy the **User UID** (looks like: `xR7pQ4mN...`)
6. Go to **Firestore Database**
7. Click **Start collection** → Collection ID: `admin_users`
8. Document ID: Paste the User UID
9. Add fields:
   ```
   email: "admin@godtrasco.com"
   name: "Godtrasco Admin"
   role: "super_admin"
   permissions: ["all", "manage_users", "manage_bookings", "manage_vans", "manage_routes", "manage_discounts", "view_analytics", "export_data"]
   isActive: true
   createdAt: [Current timestamp]
   lastLogin: null
   ```
10. Click **Save**

---

## Step 6: Test Login

1. In your running app, enter:
   - **Email:** `admin@godtrasco.com`
   - **Password:** `admin123`
2. Click **Sign In**
3. You should be redirected to the **Dashboard**

---

## Step 7: Verify Access

After logging in, verify you can access:

- ✅ Dashboard (shows stats and charts)
- ✅ Fleet Management (add/edit vans and buses)
- ✅ Booking Management (view/manage bookings)
- ✅ Route Management (add/edit routes)
- ✅ Analytics (view reports)

---

## Troubleshooting

### "Access denied. Admin privileges required."
- ❌ Admin user not created in Firestore
- ✅ Create admin user in `admin_users` collection

### "Permission denied" errors
- ❌ Security rules not set up correctly
- ✅ Copy and paste the security rules exactly as shown above

### Cannot create admin account
- ❌ Email/Password authentication not enabled
- ✅ Enable it in Authentication → Sign-in method

### Queries fail with "index required" error
- ❌ Composite indexes not created
- ✅ Click the link in the error message to auto-create, or create manually

---

## Quick Verification Commands

Check if Firebase is connected properly by opening **Chrome DevTools** (F12):

1. Go to **Console** tab
2. You should see:
   - ✅ No Firebase initialization errors
   - ✅ Firebase app name appears
   - ✅ No CORS errors

---

## Post-Setup: Change Default Password

⚠️ **IMPORTANT FOR PRODUCTION:**

After your first successful login, change the default password:

1. Go to Firebase Console → **Authentication** → **Users**
2. Find `admin@godtrasco.com`
3. Click the **3 dots menu** → **Reset password**
4. OR use the "Forgot Password" feature in the app

---

## Summary

Your app is **code-ready** and connected to Firebase project **e-ticket-ff181**.

**To complete setup:**
1. ✅ Enable Email/Password authentication
2. ✅ Create Firestore database
3. ✅ Set security rules
4. ✅ Create admin account
5. ✅ Test login

Once these steps are complete, you'll be able to login and access the full admin panel!

---

**Need Help?** Check the Firebase Console for error messages or check the browser console (F12) for detailed error logs.
