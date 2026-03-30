# SCRUM Ticket Log (Modular & Reusable)

This log is the **primary reference** for commit tracking. Before creating a new Jira ticket, check if your task fits into one of the **Reuse Blocks** below. 

> **Workflow Mandate:** If Jira Atlassian MCP is offline, **ALWAYS** reuse the most relevant key from this file.

---

## 🔄 Evergreen Reuse Blocks
*Use these keys for all standard maintenance, polish, and ongoing development.*

### 🛠️ Admin & Management
- **[SCRUM-114]** **REUSABLE:** Admin App Development (Dashboard, Service Hub, Audit Logs).
- **[SCRUM-88]** Admin App Resilience & Leaderboard Refresh.
- **[SCRUM-38/39]** Admin App & Backend placeholders.

### 🌐 Backend & Infrastructure
- **[SCRUM-115]** **REUSABLE:** Backend & API Development (FastAPI, Firebase, Security Hardening).
- **[SCRUM-99]** Firestore & Backend Hardening (Rules, Schema).
- **[SCRUM-65]** Modular Backend Refactor (DDD-lite).

### 🎨 Game Frontend & UI
- **[SCRUM-116]** **REUSABLE:** Game Frontend Development (UI Polish, Widgets, Flame Engine).
- **[SCRUM-108/109]** Frontend Modularization (Dashboard Refactoring).
- **[SCRUM-66/67]** Snackbar Management & Feedback.

### 💰 Economy & Rewards
- **[SCRUM-117]** **REUSABLE:** Economy System & Shop Development (Roulette, Shop, Currency Sync).
- **[SCRUM-56-59]** Roulette & Offline-First Implementation.
- **[SCRUM-47/48]** Core Economy & Security Validation.

### 🧹 Repository & Health
- **[SCRUM-118]** Repository Cleanup & Maintenance (Gemini Mandate Compliance) - Done
- **[SCRUM-68]** Project Cleanup & Build Optimization.

### 📝 Documentation
- **[SCRUM-119]** **REUSABLE:** Documentation Updates (README, CHANGELOG, Component Guides).
- **[SCRUM-100]** Schema Documentation (FIRESTORE.md).

---

## 📜 Complete Ticket Index (Reference & Individual Reuse)
*The full list of individual tickets for specific one-off tasks or historical reference.*

- **[SCRUM-1]** Game Level Map Assets - Done
- **[SCRUM-3]** Authentication - Done
- **[SCRUM-5]** Login Screen UI/UX - Done
- **[SCRUM-6]** Registration Screen UI/UX - Done
- **[SCRUM-7]** Splash Screen UI/UX - Done
- **[SCRUM-8]** Loading Screen UI/UX - Done
- **[SCRUM-9]** Tiled Assets - Done
- **[SCRUM-10]** Main Dashboard UI/UX - Done
- **[SCRUM-11]** Profile UI/UX - Done
- **[SCRUM-13]** Configure Game Assets in pubspec.yaml - Done
- **[SCRUM-14]** Implement DreamHunterGame Controller - Done
- **[SCRUM-15]** Create GameScreen and UI Integration - Done
- **[SCRUM-16]** Implement Camera and Character Rendering - Done
- **[SCRUM-17]** Player Controller & Physics - Done
- **[SCRUM-18]** Collision Detection (Environment) - Done
- **[SCRUM-34]** setup-flame-game - Done
- **[SCRUM-35]** Clean upp - Done
- **[SCRUM-36]** backend implmentation - Done
- **[SCRUM-37]** global-chat-system - Done
- **[SCRUM-38]** admin app - Done
- **[SCRUM-39]** admin backend - Done
- **[SCRUM-40]** Shop UI Enhancement: Fix spacing and add currency display - Done
- **[SCRUM-41]** UI: Fix Currency HUD Visibility in AppBar - Done
- **[SCRUM-42]** UI: Redesign Currency HUD for aesthetic fit - Done
- **[SCRUM-43]** UI: Vertical Currency HUD alignment and Purchase Button addition - Done
- **[SCRUM-44]** UI: Precision alignment of Currency HUD with Menu Button - Done
- **[SCRUM-45]** UI: Add Purchase Button for Normal Coins (Token to Coin Exchange) - Done
- **[SCRUM-46]** moderator toggle doesnt work in admin app - Done
- **[SCRUM-47]** Implement DreamHunter Economy & Shop System - Done
- **[SCRUM-48]** Implement Economy & Shop System with Security Validation - Done
- **[SCRUM-49]** Add purchase confirmation for items > 500 coins - Done
- **[SCRUM-50]** Fix horizontal overflow on 'PUBLISH TO SHOP' button - Done
- **[SCRUM-51]** Implement Leaderboard Screen and Dashboard Navigation in Admin App - Done
- **[SCRUM-52]** Add playtime field to User Model - Done
- **[SCRUM-53]** Add Drawer Menu with Leaderboard Navigation to Admin App - Done
- **[SCRUM-54]** Add Leaderboard to Frontend Sandwich Menu - Done
- **[SCRUM-55]** Fix shop balance check mismatch (Insufficient Coins error) - Done
- **[SCRUM-56]** Implement Roulette & Daily Rewards System - Done
- **[SCRUM-57]** Make Roulette fully offline compatible - Done
- **[SCRUM-58]** Enhance Frontend Offline-First Architecture - Done
- **[SCRUM-59]** Finalize Simplified Offline-First Strategy - Done
- **[SCRUM-60]** skur - Done
- **[SCRUM-61]** Fix logic gaps in Offline-First architecture (Multi-user & Sync UX) - Done
- **[SCRUM-62]** Implement success snackbar for login and logout - Done
- **[SCRUM-63]** Implement final cloud sync on logout - Done
- **[SCRUM-64]** Persistent Guest Session & Non-Destructive Migration - Done
- **[SCRUM-65]** Modular Backend Refactor (DDD-lite Architecture) - Done
- **[SCRUM-66]** Robust Registration Feedback & Snackbar Management - Done
- **[SCRUM-67]** CustomSnackBar Queue System Implementation - Done
- **[SCRUM-68]** Fix login type cast error and backend sync typos - Done
- **[SCRUM-69]** Fix Auth Snackbar Redundancy & Logic Gaps - Done
- **[SCRUM-70]** Global Leaderboard Implementation - Done
- **[SCRUM-71]** Daily Tasks and Predefined Profile Customization - Done
- **[SCRUM-72]** Implement Online Status Indicator in HUD - Done
- **[SCRUM-73]** Adjust Splash Loading Bar & Fix Connectivity Plugin Linkage - Done
- **[SCRUM-74]** Fix Profile Avatar Change Issue - Done
- **[SCRUM-75]** Finalize Avatar Source of Truth Logic - Done
- **[SCRUM-76]** Show user standing in leaderboard - Done
- **[SCRUM-77]** Liquid Glass Save Conflict Resolver Implementation - Done
- **[SCRUM-78]** Service Operations, Global Config & Chat Anti-Spam - Done
- **[SCRUM-79]** Economy Injection & Shadow Hash Recalculation - Done
- **[SCRUM-80]** Superban (Online-only ban) Implementation - Done
- **[SCRUM-81]** Moderator Hierarchy Implementation - Done
- **[SCRUM-82]** Auto-Mod Strike System & UX Persistence - Done
- **[SCRUM-83]** Save Tweak & Admin Surprise Flow - Done
- **[SCRUM-84]** Leaderboard Repair & Admin App Type Fixes - Done
- **[SCRUM-85]** Code Cleanup & UI Responsiveness Fixes - Done
- **[SCRUM-86]** Logic Gaps & Audit Trail Fixes - Done
- **[SCRUM-87]** Leaderboard & Stats Aggregation Final Fixes - Done
- **[SCRUM-88]** Admin App Resilience & Leaderboard Refresh - Done
- **[SCRUM-89]** Economy Injection & Shadow Hash Recalculation (Mapped) - Done
- **[SCRUM-90]** Superban (Online-only ban) Implementation (Mapped) - Done
- **[SCRUM-91]** Moderator Hierarchy Implementation (Mapped) - Done
- **[SCRUM-92]** Auto-Mod Strike System & UX Persistence (Mapped) - Done
- **[SCRUM-93]** Save Tweak & Admin Surprise Flow (Mapped) - Done
- **[SCRUM-94]** Leaderboard Repair & Admin App Type Fixes (Mapped) - Done
- **[SCRUM-95]** Code Cleanup & UI Responsiveness Fixes (Mapped) - Done
- **[SCRUM-96]** Logic Gaps & Audit Trail Fixes (Mapped) - Done
- **[SCRUM-97]** Admin App Resilience & Leaderboard Refresh (Mapped) - Done
- **[SCRUM-98]** Leaderboard & Stats Aggregation Final Fixes (Mapped) - Done
- **[SCRUM-99]** Firestore & Backend Hardening - Done
- **[SCRUM-100]** Create docs/FIRESTORE.md schema documentation - Done
- **[SCRUM-101]** Implement strict firestore.rules - Done
- **[SCRUM-102]** Centralize Registration & Economy in FastAPI - Done
- **[SCRUM-103]** Refactor Flutter to use Backend endpoints - Done
- **[SCRUM-104]** Define Firestore indexes - Done
- **[SCRUM-105]** Refine Jira & Git workflow mandates in GEMINI.md - Done
- **[SCRUM-106]** Fix missing dart:convert import in AuthService - To Do
- **[SCRUM-107]** Project Ground-Up Reset Phase 1: Cleanup - To Do
- **[SCRUM-108]** Frontend Modularization: Dashboard Refactoring - Phase 1 - Done
- **[SCRUM-109]** Frontend Modularization: Dashboard Refactoring - Phase 2 (State Management) - Done
- **[SCRUM-110]** FE: Implement Hell Stone to Dream Coin Exchange functionality - In Progress
- **[SCRUM-111]** Refactor RouletteDialog UI for Persistent Spins & Refill Button - Done
- **[SCRUM-112]** Roulette Persistence & Daily Refill Logic (Backend/Service) - Done
- **[SCRUM-113]** Reusable InsufficientFundsDialog and Roulette Refactoring - To Do
- **[SCRUM-118]** Enable background spin completion on Dashboard - Done
- **[SCRUM-119]** Final Roulette optimizations and race condition fixes - Done
- **[SCRUM-120]** Fixed 'developer' import error and context sync lints - Done
- **[SCRUM-121]** Fix BGM playlist (typo, focus resilience, seamless transitions & Android-only context) - Done
- **[SCRUM-122]** Increase base music volume by 10% (0.72 -> 0.79) & Verify SFX Max - Done
