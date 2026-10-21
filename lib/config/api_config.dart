class ApiConfig {
  // Live Vercel Backend URL (configurable via --dart-define=API_BASE_URL=...)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://finfamily-backend.vercel.app/api',
  );
  
  // Timeout settings
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Google OAuth Client Configuration (Web Client ID for server-side token generation)
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '53561071157-bf7r6nmn7111sgk5174gtgfunr260i06.apps.googleusercontent.com',
  );

  // App Version & Release Configuration (FF-05 & FF-31: Single Source of Truth)
  static const String currentAppVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.1.3');
  static const int currentAppBuildNumber = int.fromEnvironment('APP_BUILD_NUMBER', defaultValue: 11);

  // Auth endpoints
  static const String parentRegister = '/auth/register';
  static const String parentLogin = '/auth/login';
  static const String googleLogin = '/auth/google';
  static const String childLogin = '/auth/child/login';
  static const String childLookup = '/auth/child/lookup';
  static const String currentUser = '/auth/me';
  static const String familyCode = '/auth/family/code';
  static const String familyChildren = '/auth/family/children';
  static const String createChild = '/auth/children';
  static const String mfaStatus = '/auth/mfa/status';
  static const String mfaSetup = '/auth/mfa/setup';
  static const String mfaEnable = '/auth/mfa/enable';
  static const String mfaVerify = '/auth/mfa/verify';
  static const String mfaDisable = '/auth/mfa/disable';
  static const String mfaRecoveryRegenerate = '/auth/mfa/recovery-codes/regenerate';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String changePassword = '/auth/parent/change-password';

  // Family & Parent endpoints
  static const String familyOverview = '/family/overview';
  static const String familyInsights = '/family/insights';
  static const String familyActivity = '/family/activity';
  static const String familyMembers = '/family/members';
  static const String familyCards = '/family/cards';
  static const String allowances = '/family/allowances';
  static const String instantAllowance = '/family/allowances/instant';
  static const String spendingLimits = '/family/spending-limits';
  static const String approvals = '/family/approvals';
  static const String auditLogs = '/audit-logs';
  static const String missionsFamily = '/missions/family';
  static const String missionsCreate = '/missions';
  static const String cardPurchasesFamily = '/card/purchases/family';

  // Child & Gamification endpoints
  static const String walletMe = '/wallet/me';
  static const String missionsMine = '/missions/mine';
  static const String transactionsMine = '/transactions/mine';
  static const String goalsMe = '/wallet/me/goals';
  static const String gamesComplete = '/games/complete';
  static const String badgesMine = '/badges/mine';
  static const String cardPurchasesMine = '/card/purchases/mine';
  static const String missions = '/missions';
  static const String goals = '/wallet/me/goals';
  static const String transactions = '/transactions/mine';
  static const String aiCoach = '/functions/aiCoach';
  static const String appVersion = '/app/version';

  // Super Admin Endpoints
  static const String adminOverview = '/admin/overview';
  static const String adminCards = '/admin/cards';
  static const String adminTransactions = '/admin/transactions';
  static const String adminDbHealth = '/admin/database/health';
  static const String adminSecurityAlerts = '/admin/security/alerts';
  static const String adminLogin = '/admin/auth/login';

  // Dynamic route helpers
  static String missionSubmit(String id) => '/missions/$id/submit';
  static String missionReview(String id) => '/missions/$id/review';
  static String cardPurchaseReview(String id) => '/card/purchases/$id/review';
  static String childWallet(String childId) => '/wallet/child/$childId';
  static String childWalletLimits(String childId) => '/wallet/child/$childId/limits';
  static String childCardStatus(String childId) => '/wallet/child/$childId/card-status';
  static String childCardReplace(String childId) => '/wallet/child/$childId/card/replace';
  static String childAllowance(String childId) => '/wallet/child/$childId/allowance';
  static String goalDeposit(String goalId) => '/wallet/me/goals/$goalId/deposit';
  static String goalWithdraw(String goalId) => '/wallet/me/goals/$goalId/withdraw';
  static String goalDelete(String goalId) => '/wallet/me/goals/$goalId';
}
