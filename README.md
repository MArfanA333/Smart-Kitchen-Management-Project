# 🍽️ Smart Kitchen: Food Management System

An IoT- and AI-enabled smart kitchen system designed to tackle food waste, simplify inventory tracking, and assist with meal planning and shopping — all controlled via a Flutter-based mobile application.

---

## 📄 Project Overview

This project reduces food waste and streamlines kitchen management using smart sensors, computer vision, and a mobile interface. It includes automated food recognition, expiration tracking, meal planning, and real-time monitoring of environmental conditions such as temperature, humidity, and spoilage indicators.

### Key Features:
- Inventory detection using weight and object recognition
- Expiration date tracking and smart alerts
- Personalized meal planning and recipe suggestions
- Auto-generated shopping lists
- Environment monitoring for food safety
- Real-time sync and interaction via a Flutter mobile app

---

## 📁 Folder Structure

```plaintext
Smart-Kitchen-Management-Project/
├── application/                # Flutter mobile application
│
├── uploadscript/              # Data scripts for Firebase
├── Design Plan Smart Kitchen Management Plan # Report for design phase of project
├── Implementation Smart Kitchen Management Plan # Report for Implementation phase of project
└── README.md                  # This file
````

---

## ✅ Project Requirements

### Functional Requirements:

* Monitor food via sensors, cameras, and weight pads
* Allow user edits for items, recipes, and expiry dates
* Alert users for expiring or depleted inventory
* Recommend recipes using available or near-expiry items
* Generate shopping lists for missing meal plan items
* Allow full interaction through mobile app

### Non-Functional Requirements:

* Real-time updates within 2 seconds
* Secure storage and encrypted data transmission
* Support for at least 100 concurrent users
* OTA software updates
* Cross-platform (Android, iOS, web) accessibility
* Modular design for ease of maintenance
* Synchronization across all devices

---

## 🧪 Technologies Used

| Layer            | Technology                             |
| ---------------- | -------------------------------------- |
| Frontend (App)   | Flutter                                |
| Backend          | Firebase (Firestore, Auth, Storage)    |
| Edge Processing  | Python (on Raspberry Pi)               |
| Microcontroller  | Arduino Giga R1                        |
| Sensors          | SHT30, MQ-3, MQ-214, HX711 + Load Cell |
| Object Detection | YOLOv11 (on RPi Camera Module 3)       |
| Vision Module    | Eufy 360-Tilt Camera, OV3660 Camera    |

---

## 📱 Mobile App

The Flutter app serves as the user interface, enabling:

* Real-time inventory viewing
* Expiry notifications
* Smart recipe suggestions
* Manual item entry/editing
* Smart shopping list management

---

## 👥 Team & Contributions
**Developed by students at the American University of Sharjah:**

* **Mohammad Arfan Ameen**
* **Farzaan Siddiqui**
* **Adithya Sankar**
* **Kareem Ahmed**

**Advisor:** Dr. Michel Pasquier
---
