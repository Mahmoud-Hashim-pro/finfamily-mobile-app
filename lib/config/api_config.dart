class ApiConfig {
  // Live Vercel Backend URL
  static const String baseUrl = 'https://finfamily-backend.vercel.app/api';
  
  // Timeout settings
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Auth endpoints
  static const String parentRegister = '/auth/register';
  static const String parentLogin = '/auth/login';
  static const String childLogin = '/auth/child/login';
  static const String childLookup = '/auth/child/lookup';
  static const String currentUser = '/auth/me';
  static const String familyCode = '/auth/family/code';
  static const String familyChildren = '/auth/family/children';
  static const String createChild = '/auth/children';
  static const String mfaSetup = '/auth/mfa/setup';
  static const String mfaEnable = '/auth/mfa/enable';
  static const String mfaVerify = '/auth/mfa/verify';
  static const String mfaDisable = '/auth/mfa/disable';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // Family & Parent endpoints
  static const String familyOverview = '/family/overview';
  static const String familyMembers = '/family/members';
  static const String familyCards = '/family/cards';
  static const String allowances = '/family/allowances';
  static const String instantAllowance = '/family/allowances/instant';
  static const String spendingLimits = '/family/spending-limits';
  static const String approvals = '/family/approvals';
  static const String auditLogs = '/family/audit-logs';

  // Child & Gamification endpoints
  static const String missions = '/family/missions';
  static const String goals = '/family/goals';
  static const String transactions = '/family/transactions';
  static const String aiCoach = '/functions/aiCoach';
}
