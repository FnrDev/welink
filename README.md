# WeLink – iOS Application

WeLink is an iOS application designed to help people find and offer local services.  
Users can join the platform as either **Providers** or **Seekers**:

- **Providers** create and publish services such as tutoring, home chores, repairs, and more.
- **Seekers** browse available services, view details, and book the services they need.

The app is built using **Swift**, **Storyboard**, and integrates **Supabase** as the backend for authentication, database, and storage.

---

## Features

### 👤 User Roles

#### Provider
- Create and manage service listings.
- Set service descriptions, pricing, availability, and location.
- Receive and manage booking requests.
- View service history and customer reviews.

#### Seeker
- Browse nearby services by category or search.
- View detailed provider profiles and service information.
- Book services and track request status.
- Save favorite services for later.

---

## Main Features

| # | Feature | Description | Developer | Tester |
|---|--------|-------------|-----------|--------|
| 1 | User Authentication & Profile Setup | Signup, login, and profile management for all user roles | Ali | Zahra Almosawi |
| 2 | Seeker Home & Service Discovery | Browse, search, and filter services by category and location | Zahra Almosawi | Rawan |
| 3 | Provider Dashboard | Manage services, bookings, availability, and view history | Ahmed Abdulla | Zahra M |
| 4 | Communication System | Real-time chat between seekers and providers | Ahmed Abdulla | Zahra Almosawi |
| 5 | Service History & Favorites | View booking history and save favorite services | Zahra M | Ali |
| 6 | Admin Dashboard | Manage users, services, and platform data | Rawan | Ahmed Abdulla |
| 7 | Provider Profile | Public provider profile with services and reviews | Ali | Zahra M |
| 8 | Notifications Page | Booking updates and system notifications | Ahmed, Rawan | Rawan |
| 9 | Payment System | Secure payments and booking payment tracking | Zahra Almosawi | Ali |

---

## Additional Features

| # | Feature | Description | Developer |
|---|--------|-------------|-----------|
| 1 | Smart Service Recommendations | Personalized service suggestions based on user behavior | Zahra Almosawi |
| 2 | Review & Rating System | Rate and review providers after service completion | Zahra Almosawi |
| 3 | Admin Activity Log | Track admin actions and system changes | Rawan Mahmood |
| 4 | Admin Moderation Notes & Flags | Flag users/services and add internal moderation notes | Rawan Mahmood |

---

## Tech Stack

- **iOS:** Swift, Storyboard-based UI
- **Backend:** Supabase (Auth, Database, Storage)
- **Networking:** URLSession / Supabase iOS SDK
- **State Management:** UIKit (MVC)

---

## Supabase Integration

WeLink uses Supabase for:
- Authentication (Email & Password)
- Database (Users, Services, Bookings, Categories, Reviews)
- Storage (Profile images and service media)
- Real-time Events (Chat messages)
- Edge Functions (Admin-related operations)

---

## Testing

- **Simulator Used:** iPhone 16 Pro

---

## Login Credentials (Testing)

- **Seeker Account:** seeker@welink.com | pass123  
- **Provider Account:** provider@welink.com | pass123  
- **Admin Account:** admin@welink.com | pass123
