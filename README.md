# FinFamily Mobile App 👨‍👩‍👧‍👦💳

**FinFamily** is Egypt's first digital financial-literacy mobile platform empowering parents with smart financial oversight and giving children (ages 6–15) their first simulated open-loop **Meeza Card**, missions, savings goals, and gamified financial education.

Built with **Flutter & Dart**, connecting directly to the production **FastAPI + PostgreSQL** backend.

---

## 🌟 Key Features

### 👪 Parent Portal
* **Family Dashboard**: Real-time family overview, total balance, spending trends, and quick allowance transfers.
* **Smart Allowance**: Instant one-tap transfers ("Disburse Now") with scheduled automated distribution on the roadmap.
* **Granular Spending Limits**: Daily, weekly, and monthly limits per child with category-based restrictions (e.g. block Gaming or Fast Food).
* **Card Controls**: Instant freeze, unfreeze, PIN reset, and deactivation for simulated Meeza cards.
* **Approvals Hub**: Review and approve/reject chore submissions, reward redemptions, and high-value transactions.
* **AI Parent Coach**: Financial parenting assistant with family-specific context.
* **Two-Factor Authentication (2FA)**: Mandatory for Administrators, optional & recommended for Parents (TOTP-based via Google/Microsoft Authenticator & backup recovery codes).

### 🧒 Child Experience
* **Child Home**: Friendly greeting, level progression, streaks, and quick action cards.
* **Interactive Meeza Card**: 3D flip card animation with live masked card details, freeze toggle, POS purchase simulator, and spend logs.
* **Missions & Chores**: Complete tasks to earn pocket money (requires parent approval) and request reward redemptions.
* **Savings Goals**: Visual piggy bank tracker with goal timelines and AI-driven saving tips.
* **Learn & Mini-Games**: 6 comprehensive financial literacy curriculum modules and 10 interactive educational mini-games (Needs vs. Wants, Guess the Price, Budget Challenge, Scam Detective, etc.).
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
git clone https://github.com/Mahmoud-Hashim-pro/finfamily-mobile-app.git
cd finfamily-mobile-app

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
