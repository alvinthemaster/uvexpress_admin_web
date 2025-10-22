# Quick Firebase Setup - Deploy Indexes & Rules

## 🚀 Fast Method (Using Firebase CLI)

### Step 1: Install Firebase CLI (if not already installed)

```powershell
npm install -g firebase-tools
```

### Step 2: Login to Firebase

```powershell
firebase login
```

This will open your browser for authentication.

### Step 3: Initialize Firebase in Your Project

```powershell
cd C:\Users\yourb\OneDrive\Documents\GitHub\uvexpress_admin_web
firebase init
```

**During initialization:**
1. Select: **Firestore** (use Space to select, Enter to confirm)
2. Select existing project: **e-ticket-ff181**
3. For Firestore rules file: Press **Enter** (use `firestore.rules` - already created!)
4. For Firestore indexes file: Press **Enter** (use `firestore.indexes.json` - already created!)

### Step 4: Deploy Everything at Once

```powershell
firebase deploy --only firestore
```

This will deploy:
- ✅ Security rules
- ✅ All 6 composite indexes
- ✅ Takes ~30 seconds total!

---

## 📋 Alternative: Manual Method (Firebase Console)

If you prefer not to use Firebase CLI, here's the quick manual way:

### Deploy Security Rules (1 minute)

1. Go to [Firebase Console](https://console.firebase.google.com/project/e-ticket-ff181/firestore)
2. Click **Rules** tab
3. Copy ALL content from `firestore.rules` file
4. Paste into the editor
5. Click **Publish**

### Deploy Indexes (2 minutes)

1. In Firebase Console, go to **Firestore Database**
2. Click **Indexes** tab
3. Click **Add Index** for each of these:

#### Index 1: Bookings by Route and Date
- Collection: `bookings`
- Fields:
  - `routeId` → Ascending
  - `travelDate` → Descending
- Click **Create**

#### Index 2: Bookings by Status and Date
- Collection: `bookings`
- Fields:
  - `status` → Ascending
  - `createdAt` → Descending
- Click **Create**

#### Index 3: Bookings by Van and Date
- Collection: `bookings`
- Fields:
  - `vanId` → Ascending
  - `travelDate` → Descending
- Click **Create**

#### Index 4: Vans by Status and Queue
- Collection: `vans`
- Fields:
  - `status` → Ascending
  - `queuePosition` → Ascending
- Click **Create**

#### Index 5: Vans by Route and Queue
- Collection: `vans`
- Fields:
  - `routeId` → Ascending
  - `queuePosition` → Ascending
- Click **Create**

#### Index 6: Routes by Active and Origin
- Collection: `routes`
- Fields:
  - `isActive` → Ascending
  - `origin` → Ascending
- Click **Create**

**Note:** Indexes may take 2-5 minutes to build after creation.

---

## ✅ Verify Deployment

After deploying, verify everything is set up:

```powershell
firebase firestore:indexes
```

This will list all your indexes and their status.

---

## 🎯 Recommended: Use Firebase CLI

**Why?**
- ✅ Much faster (30 seconds vs 5+ minutes)
- ✅ Less error-prone
- ✅ Version controlled (rules and indexes in your repo)
- ✅ Easy to update later
- ✅ Can deploy to multiple environments

---

## 📦 What's Included

I've created these files for you:

1. **`firestore.indexes.json`** - All 6 composite indexes
2. **`firestore.rules`** - Complete security rules
3. **This guide** - Deployment instructions

---

## 🚨 After Deployment

Once indexes and rules are deployed:

1. **Create Admin Account** - Use "Create Admin Account" button in your app
2. **Login** - Use `admin@godtrasco.com` / `admin123`
3. **Test Access** - Try creating a van or viewing bookings

---

## 💡 Tips

- Indexes build in the background (2-5 minutes)
- You can use the app while indexes are building
- Some queries may fail until indexes are ready
- Check index status in Firebase Console → Indexes tab
