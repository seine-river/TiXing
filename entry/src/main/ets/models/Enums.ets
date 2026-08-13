export enum Subject {
  MATH = 'math',
  CHINESE = 'chinese',
  ENGLISH = 'english',
  SCIENCE = 'science'
}

export enum Grade {
  G3 = '3',
  G4 = '4',
  G5 = '5',
  G6 = '6'
}

export enum TextbookVersion {
  PEP = 'pep',
  BJ = 'bj',
  SU = 'su',
  OTHER = 'other'
}

export enum ErrorType {
  CONCEPT = 'concept',
  CARELESS = 'careless',
  MISREAD = 'misread',
  OTHER = 'other'
}

export enum MistakeStatus {
  UNMASTERED = 'unmastered',
  REVIEWING = 'reviewing',
  MASTERED = 'mastered'
}

export enum AnswerType {
  CHOICE = 'choice',
  NUMERIC = 'numeric',
  TEXT = 'text',
  SUBJECTIVE = 'subjective'
}

export enum GradingMethod {
  OBJECTIVE_AUTO = 'objective_auto',
  SUBJECTIVE_SELFREPORT = 'subjective_selfreport'
}

export enum InputMethod {
  SELECT = 'select',
  NUMERIC_KEYPAD = 'numeric_keypad',
  HANDWRITING = 'handwriting',
  VOICE = 'voice',
  KEYBOARD = 'keyboard'
}

export enum SyncStatus {
  SYNCED = 'synced',
  PENDING = 'pending',
  CONFLICT = 'conflict'
}

export enum PointsActionType {
  CAPTURE = 'capture',
  ON_TIME_REVIEW = 'on_time_review',
  MASTERY_ACHIEVED = 'mastery_achieved',
  STREAK = 'streak',
  COMMUNITY_CONTRIBUTION = 'community_contribution'
}

export enum CommunityPostStatus {
  PENDING_PARENT_CONFIRM = 'pending_parent_confirm',
  PENDING_REVIEW = 'pending_review',
  PUBLISHED = 'published',
  REJECTED = 'rejected'
}

export enum SubscriptionPlanType {
  MONTHLY = 'monthly',
  SEMESTER = 'semester',
  ANNUAL = 'annual',
  SINGLE_REPORT = 'single_report'
}

export enum SubscriptionStatus {
  NONE = 'none',
  ACTIVE = 'active',
  EXPIRED = 'expired'
}

export enum Trend {
  IMPROVING = 'improving',
  STABLE = 'stable',
  DECLINING = 'declining'
}

export enum ContentType {
  PRINTED_TEXT = 'printed_text',
  FORMULA = 'formula',
  HANDWRITING = 'handwriting'
}

export enum ImageQualityIssue {
  BLUR = 'blur',
  TILT = 'tilt',
  GLARE = 'glare',
  LOW_LIGHT = 'low_light'
}
