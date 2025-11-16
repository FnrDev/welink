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
- Receive booking requests from seekers.

#### Seeker
- Browse nearby services by category or search.
- View detailed provider profiles and service descriptions.
- Book and track service requests.

---

## Tech Stack

- **iOS:** Swift, Storyboard-based UI
- **Backend:** Supabase (Auth, Database, Storage)
- **Location:** CoreLocation for nearby service discovery
- **Networking:** URLSession / Supabase iOS SDK
- **State Management:** UIKit patterns (MVC)

---

## Supabase Integration

WeLink uses Supabase for:
- **Authentication:** Email/password login & signup
- **Database:** Storing services, users, bookings, and categories
- **Storage:** Provider profile photos and media files
- **Real-time Events:** For user presence (🟢 Online, 🔴 Offline)
