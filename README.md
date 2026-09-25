# FinFamily Mobile App 👨‍👩‍👧‍👦💳

**FinFamily** is Egypt's first digital financial-literacy mobile platform empowering parents with smart financial oversight and giving children (ages 6–15) their first simulated open-loop **Meeza Card**, missions, savings goals, and gamified financial education.

Built with **Flutter & Dart**, connecting directly to the production **FastAPI + PostgreSQL** backend.

---

## 🌟 Key Features

### 👪 Parent Portal
* **Family Dashboard**: Real-time family overview, total balance, spending trends, and quick allowance transfers.
* **Smart Allowance**: Automated weekly/monthly allowance distribution or instant one-tap transfers.
* **Granular Spending Limits**: Daily, weekly, and monthly limits per child with category-based restrictions (e.g. block Gaming or Fast Food).
* **Card Controls**: Instant freeze, unfreeze, PIN reset, and deactivation for simulated Meeza cards.
* **Approvals Hub**: Review and approve/reject chore submissions, reward redemptions, and high-value transactions.
* **AI Parent Coach**: Financial parenting assistant with family-specific context.
* **Mandatory 2FA**: TOTP-based two-factor authentication (Google/Microsoft Authenticator) & recovery codes.

### 🧒 Child Experience
* **Child Home**: Friendly greeting, level progression, streaks, and quick action cards.
* **Interactive Meeza Card**: 3D flip card animation with live masked card details, freeze toggle, and spend logs.
* **Missions & Chores**: Complete tasks to earn pocket money (requires parent approval).
* **Savings Goals**: Visual piggy bank tracker with goal timelines and AI-driven saving tips.
* **Learn & Mini-Games**: 10 educational modules and 11 financial mini-games (Needs vs. Wants, Guess the Price, Budget Builder, etc.).
* **AI Kid Coach**: Safe, bilingual financial buddy for answering money questions.
* **Sibling Leaderboard**: Friendly competition to promote smart saving habits.

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (3.10.0 or higher)
* Dart SDK (3.0.0 or higher)
* Android Studio / Xcode / VS Code with Flutter extension

### Installation & Run

```bash
# 1. Clone the repository
git clone https://github.com/<your-username>/FinFamily-Mobile.git
cd FinFamily-Mobile

# 2. Install dependencies
flutter pub get

# 3. Run on your connected device or emulator
flutter run
```

### Backend Configuration
The app is configured by default to connect to the live backend:
```dart
// lib/config/api_config.dart
static const String baseUrl = 'https://fin-family.app/api';
```
You can switch it to `http://10.0.2.2:8000/api` for local Android emulator development.
