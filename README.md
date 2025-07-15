# VBus – University Bus Tracking App

VBus is a real-time bus tracking system built for **VIT Bhopal University**. It streamlines bus travel for students, faculty, and conductors by offering real-time updates, seat booking, attendance management, and more — all within a unified Flutter app.

**Note**: This project is currently being rebuilt with enhanced features and improved architecture. Check out the new version [here](https://github.com/viyxsh/vbus_rebuilt).

---

## Features

### For Students and Faculty
- Google Sign-In using university email (`@vitbhopal.ac.in`)
- Bus route map with live tracking
- Real-time bus stop updates
- Seat booking
- Notifications for bus arrival
- Profile setup and editing
- Inbox and chat with conductor

### For Conductors
- Secure login with university-provided credentials
- Attendance management with QR scanning and status tracking
- Real-time passenger list with filtering options
- Bus details setup and profile editing
- Chat and inbox functionality

---

## Screenshots

Below are screenshots of the current VBus app:

| Login Page    | Map Screen     | Seat Booking Screen | Attendance Screen | Attendance Screen 2 | Inbox Screen | Profile Screen |
|----------------|----------------|--------------------|-------------------|---------------------|--------------|---------------|
| ![Login Page](https://raw.githubusercontent.com/viyxsh/VBus/main/screenshots/loginpage.png) | ![Map Screen](https://raw.githubusercontent.com/viyxsh/VBus/main/screenshots/mapscreen.png) | ![Seat Booking Screen](https://raw.githubusercontent.com/viyxsh/VBus/main/screenshots/seatbookingscreen.png) | ![Attendance Screen](https://raw.githubusercontent.com/viyxsh/VBus/main/screenshots/attenscreen.png) | ![Attendance Screen 2](https://raw.githubusercontent.com/viyxsh/VBus/main/screenshots/attenscreen2.png) | ![Inbox Screen](https://raw.githubusercontent.com/viyxsh/VBus/main/screenshots/inboxscreen.png) | ![Profile Screen](https://raw.githubusercontent.com/viyxsh/VBus/main/screenshots/profilescreen.png) |

---

## Project Structure Overview

| File | Description |
|------|-------------|
| `main.dart` | Initializes Firebase, splash screen, and routes based on user authentication |
| `login_screen.dart` | Manages account type selection and login methods for students and conductors |
| `splash_screen.dart` | Displays an animated splash screen and redirects based on user status |
| `student_app.dart` | Bottom navigation for students: Map, Inbox, Seat Booking, Profile |
| `conductor_app.dart` | Bottom navigation for conductors: Map, Inbox, Attendance, Profile |
| `map.dart` | Bus route display with live location and stop status |
| `seat_booking_screen.dart` | Handles seat booking with timer and auto-allocation |
| `bus1_layout.dart` | Displays bus seating layout with interactive seat widgets |
| `seat_widget.dart` | Interactive widget to represent and manage individual seat states |
| `notifications.dart` | Sends alerts for bus arrivals |
| `attendance_screen.dart` | Manages attendance, stop tracking, and QR scanning |
| `chat_screen.dart` | Chat interface with messaging, calling, and voice support |
| `inbox.dart` | Displays all user chats |
| `profile_screens.dart` | Profile viewing for student and conductor with options |
| `edit_profile_screens.dart` | Allows users to edit personal and bus-related information |
| `student/profile_setup.dart` | Student profile setup with bus details and Firestore integration |
| `conductor/profile_setup.dart` | Conductor profile setup with bus and personal info |

---

## Tech Stack

- **Flutter** (Frontend UI)
- **Firebase Auth** (Authentication)
- **Firebase Firestore** (Database)
- **Firebase Storage** (Image and file uploads)
- **Google Maps / flutter_map** (Map integration)

---

## Future Improvements

- Real-time bus location updates using GPS
- Bus delay statistics and wait request analytics
- Hindi language support for conductors