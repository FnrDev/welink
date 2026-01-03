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

1. **User Authentication & Profile Setup**
   - Secure signup and login for all user roles
   - Profile creation and management  
   - Developer: Ali  
   - Tester: Zahra Almosawi  

2. **Seeker Home & Service Discovery**
   - Browse services by category and location
   - Search and filter services  
   - Developer: Zahra Almosawi  
   - Tester: Rawan  

3. **Provider Dashboard**
   - Manage services, bookings, and availability
   - View performance and service history  
   - Developer: Ahmed Abdulla  
   - Tester: Zahra M  

4. **Communication System**
   - Real-time chat between seekers and providers
   - Booking-related messaging  
   - Developer: Ahmed Abdulla  
   - Tester: Zahra Almosawi  

5. **Service History & Favorites**
   - Track past bookings
   - Save and manage favorite services  
   - Developer: Zahra M  
   - Tester: Ali  

6. **Admin Dashboard**
   - Manage users, services, and platform data
   - View system activity and statistics  
   - Developer: Rawan  
   - Tester: Ahmed Abdulla  

7. **Provider Profile**
   - Public provider profiles with services and reviews
   - Profile photo and details  
   - Developer: Ali  
   - Tester: Zahra M  

8. **Notifications Page**
   - Booking updates and system notifications  
   - Developers: Ahmed, Rawan  
   - Tester: Rawan  

9. **Payment System**
   - Secure service payments
   - Booking payment tracking  
   - Developer: Zahra Almosawi  
   - Tester: Ali  

---

## Additional Features

1. **Smart Service Recommendations**
   - Personalized service suggestions based on user behavior  
   - Developer: Zahra Almosawi  

2. **Review & Rating System**
   - Rate and review providers after service completion  
   - Developer: Zahra Almosawi  

3. **Admin Activity Log**
   - Track admin actions and system changes  
   - Developer: Rawan Mahmood  

4. **Admin Moderation Notes & Flags**
   - Flag services or users
   - Internal moderation notes for admins  
   - Developer: Rawan Mahmood  

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
