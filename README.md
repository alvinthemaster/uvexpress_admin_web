# UVExpress Admin Web Panel

A comprehensive Flutter Web admin panel for managing the UVExpress e-ticket booking system. This panel provides real-time van management, booking oversight, route administration, and analytics dashboard.

![UVExpress Admin Panel](https://img.shields.io/badge/Flutter-Web-blue) ![Firebase](https://img.shields.io/badge/Firebase-Backend-orange) ![Status](https://img.shields.io/badge/Status-In%20Development-yellow)

## 🚀 Features

### ✅ **Implemented Features**
- **Authentication System**: Secure admin login with role-based access
- **Dashboard**: Real-time statistics, charts, and quick actions
- **Van Management**: Fleet management with queue positioning
- **Navigation**: Responsive sidebar with user profile management
- **Real-time Data**: Live updates across all modules
- **Material Design 3**: Modern and clean UI

### 🚧 **In Development**
- Booking Management Screen
- Route Management System
- Discount Administration
- Advanced Analytics & Reports
- Export Functionality

## 🏗️ Architecture

### **Technology Stack**
- **Frontend**: Flutter Web
- **Backend**: Firebase (Firestore, Auth, Storage)
- **State Management**: Provider Pattern
- **Navigation**: GoRouter
- **Charts**: FL Chart
- **UI Framework**: Material Design 3

### **Project Structure**
```
lib/
├── models/           # Data models (Van, Booking, Route, etc.)
├── services/         # Firebase service layer
├── providers/        # State management providers
├── screens/          # Main application screens
├── widgets/          # Reusable UI components
│   ├── dashboard/    # Dashboard-specific widgets
│   └── layouts/      # Layout components
├── utils/           # Constants, helpers, utilities
└── main.dart        # Application entry point
```

## 🔥 Firebase Integration

### **Collections Schema**
- **`vans`**: Vehicle management and queue tracking
- **`routes`**: Route definitions and pricing
- **`bookings`**: Passenger bookings and payments
- **`discounts`**: Discount rules and usage tracking
- **`admin_users`**: Admin access and permissions
- **`analytics`**: Daily statistics and metrics

### **Real-time Features**
- Live van queue updates
- Instant booking status changes
- Real-time revenue tracking
- Dynamic dashboard metrics

## 📋 Prerequisites

Before running this project, make sure you have:

- **Flutter SDK** 3.1 or higher
- **Dart** 3.0+
- **Firebase CLI** (for deployment)
- **Web browser** (Chrome recommended)
- **Firebase Project** with Firestore enabled

## 🛠️ Installation

### 1. Clone the Repository
```bash
git clone <repository-url>
cd uvexpress_admin_web
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Firebase Configuration

#### Option A: Use Existing Configuration
The project already includes Firebase configuration for the UVExpress project:
- Project ID: `e-ticket-2e8d0`
- Configuration is in `lib/firebase_options.dart`

#### Option B: Setup Your Own Firebase Project
1. Create a new Firebase project
2. Enable Firestore, Authentication, and Storage
3. Update `lib/firebase_options.dart` with your credentials
4. Set up Firestore security rules (see `ADMIN_IDS.md`)

### 4. Run the Application
```bash
flutter run -d chrome
```

## 🔐 Admin Access

### **Default Admin Credentials**
To access the admin panel, you need to create an admin user in your Firebase project:

1. **Create Admin User in Firestore**:
   - Collection: `admin_users`
   - Document ID: `<user_uid>`
   - Fields:
     ```json
     {
       "email": "admin@uvexpress.com",
       "name": "Admin User",
       "role": "super_admin",
       "permissions": ["all"],
       "isActive": true,
       "createdAt": "2025-01-01T00:00:00Z"
     }
     ```

2. **Create Authentication User**:
   - Use Firebase Console to create a user with the same email
   - Set a secure password

### **Role-Based Access**
- **`super_admin`**: Full system access
- **`route_manager`**: Route and schedule management
- **`finance_manager`**: Fare and discount management
- **`operations_manager`**: Van and driver management
- **`analyst`**: Read-only access to reports

## 📊 Dashboard Features

### **Real-time Statistics**
- Today's bookings count
- Revenue tracking
- Active van count
- Pending payments

### **Visual Analytics**
- Revenue pie chart by payment method
- Hourly booking distribution
- Van queue status
- Recent bookings timeline

### **Quick Actions**
- Add new van
- Create route
- Add discount
- Export reports

## 🚐 Van Management

### **Core Features**
- Van registration with driver details
- Queue position management
- Status tracking (Active, Maintenance, Inactive)
- Real-time queue updates
- Maintenance scheduling

### **Queue Management**
- Drag-and-drop reordering
- Move van to next position
- Send van to end of queue
- Emergency van removal

## 📱 Responsive Design

The admin panel is fully responsive and works on:
- **Desktop**: Full sidebar navigation
- **Tablet**: Collapsible sidebar
- **Mobile**: Bottom navigation (planned)

## 🔧 Development

### **Adding New Features**
1. Create data models in `lib/models/`
2. Add Firebase services in `lib/services/`
3. Create providers for state management
4. Build UI screens and widgets
5. Update navigation routes

### **Code Style**
- Follow Flutter/Dart style guidelines
- Use meaningful variable names
- Add comments for complex logic
- Implement error handling
- Write unit tests for services

### **Firebase Security Rules**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Admin users can read/write all collections
    match /{document=**} {
      allow read, write: if request.auth != null && 
        exists(/databases/$(database)/documents/admin_users/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/admin_users/$(request.auth.uid)).data.isActive == true;
    }
  }
}
```

## 🚀 Deployment

### **Firebase Hosting**
```bash
# Build for web
flutter build web

# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize hosting
firebase init hosting

# Deploy
firebase deploy
```

### **Environment Configuration**
- **Development**: Local Firebase emulator
- **Staging**: Staging Firebase project
- **Production**: Production Firebase project

## 📈 Performance

### **Optimization Features**
- Lazy loading of screens
- Efficient Firestore queries
- Real-time listener management
- Image optimization
- Code splitting

### **Monitoring**
- Firebase Analytics integration
- Performance monitoring
- Error tracking
- User behavior analysis

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

### **Development Guidelines**
- Follow the existing code structure
- Update documentation for new features
- Test on multiple browsers
- Ensure responsive design
- Add proper error handling

## 📋 Roadmap

### **Phase 1** (Current)
- [x] Project setup and architecture
- [x] Authentication system
- [x] Dashboard implementation
- [x] Basic van management
- [x] Navigation and layout

### **Phase 2** (Next)
- [ ] Complete booking management
- [ ] Route management system
- [ ] Discount administration
- [ ] Advanced search and filters
- [ ] Export functionality

### **Phase 3** (Future)
- [ ] Advanced analytics
- [ ] User management
- [ ] Notification system
- [ ] Mobile responsiveness
- [ ] Multi-language support

## 🐛 Known Issues

- Chart tooltips may not work on all browsers
- Some form validations need enhancement
- Mobile navigation needs implementation
- Print functionality pending

## 📞 Support

For support and questions:
- Create an issue in this repository
- Check the `analysis.txt` file for detailed documentation
- Review the `ADMIN_IDS.md` for Firebase configuration

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for the backend infrastructure
- Material Design team for the design system
- FL Chart for the charting library

---

**Built with ❤️ for UVExpress E-Ticket System**