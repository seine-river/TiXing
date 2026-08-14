export class AppColors {
  static readonly PRIMARY: string = '#3A7BD5';
  static readonly PRIMARY_LIGHT: string = '#5B9BE8';
  static readonly PRIMARY_DARK: string = '#2E64A8';
  static readonly GRADIENT_START: string = '#3A7BD5';
  static readonly GRADIENT_END: string = '#5BB6F0';
  static readonly SECONDARY: string = '#34C759';
  static readonly WARNING: string = '#FF9F0A';
  static readonly DANGER: string = '#F56C6C';
  static readonly BG_PAGE: string = '#F2F4F8';
  static readonly BG_CARD: string = '#FFFFFF';
  static readonly BG_CHIP: string = '#EEF2F7';
  static readonly TEXT_PRIMARY: string = '#1D2129';
  static readonly TEXT_REGULAR: string = '#4E5969';
  static readonly TEXT_SECONDARY: string = '#86909C';
  static readonly TEXT_PLACEHOLDER: string = '#C9CDD4';
  static readonly BORDER: string = '#E5E6EB';
  static readonly DIVIDER: string = '#F2F3F5';
  static readonly SHADOW: string = '#1F2A3D';
  static readonly MASTERY_MASTERED: string = '#34C759';
  static readonly MASTERY_REVIEWING: string = '#3A7BD5';
  static readonly MASTERY_UNMASTERED: string = '#F56C6C';
}

export class AppSizes {
  static readonly FONT_TITLE: number = 20;
  static readonly FONT_SUBTITLE: number = 17;
  static readonly FONT_BODY: number = 16;
  static readonly FONT_CAPTION: number = 14;
  static readonly FONT_SMALL: number = 12;
  static readonly CORNER_RADIUS: number = 16;
  static readonly CORNER_RADIUS_SM: number = 12;
  static readonly CORNER_RADIUS_XS: number = 8;
  static readonly PADDING_PAGE: number = 16;
  static readonly PADDING_CARD: number = 14;
  static readonly TOUCH_TARGET: number = 44;
}

export class AppStrings {
  static readonly APP_NAME: string = '题醒';
  static readonly TAB_HOME: string = '首页';
  static readonly TAB_CAPTURE: string = '录入';
  static readonly TAB_MISTAKES: string = '错题本';
  static readonly TAB_REPORT: string = '报告';
  static readonly TAB_PROFILE: string = '我的';
  static readonly SUBJECT_MATH: string = '数学';
  static readonly SUBJECT_CHINESE: string = '语文';
  static readonly SUBJECT_ENGLISH: string = '英语';
  static readonly SUBJECT_SCIENCE: string = '科学';
  static readonly STATUS_MASTERED: string = '已掌握';
  static readonly STATUS_REVIEWING: string = '复习中';
  static readonly STATUS_UNMASTERED: string = '未掌握';
  static readonly TODAY_REVIEW: string = '今日复习';
  static readonly START_REVIEW: string = '开始复习';
  static readonly NO_REVIEW_TODAY: string = '今天没有待复习的题目';
  static readonly TOTAL_MISTAKES: string = '总错题';
  static readonly MASTERED_COUNT: string = '已掌握';
  static readonly REVIEWING_COUNT: string = '复习中';
  static readonly CAPTURE_PHOTO: string = '拍照';
  static readonly CAPTURE_ALBUM: string = '从相册选取';
  static readonly CONFIRM_OCR: string = '核对识别结果';
  static readonly CONFIRM_COMPLETE: string = '全部核对完成';
  static readonly SAVE: string = '保存';
  static readonly REVIEW_SUBMIT: string = '提交答案';
  static readonly REVIEW_NEXT: string = '下一题';
  static readonly REVIEW_FINISH: string = '完成复习';
  static readonly CORRECT_ANSWER: string = '回答正确';
  static readonly WRONG_ANSWER: string = '回答错误';
  static readonly REVIEW_SUMMARY: string = '复习总结';
  static readonly ACCURACY: string = '正确率';
  static readonly POINTS_EARNED: string = '获得积分';
  static readonly ADD_NOTES: string = '添加讲解笔记';
  static readonly FILTER_ALL: string = '全部';
  static readonly EXPORT_DATA: string = '导出数据';
  static readonly IMPORT_DATA: string = '导入数据';
  static readonly SETTINGS: string = '设置';
  static readonly LEARNING_PROFILE: string = '学习档案';
  static readonly PARENT_CENTER: string = '家长中心';
  static readonly POINTS_CENTER: string = '积分中心';
}

export function subjectLabel(subject: string): string {
  if (subject === 'math') return AppStrings.SUBJECT_MATH;
  if (subject === 'chinese') return AppStrings.SUBJECT_CHINESE;
  if (subject === 'english') return AppStrings.SUBJECT_ENGLISH;
  if (subject === 'science') return AppStrings.SUBJECT_SCIENCE;
  return subject;
}

export function statusLabel(status: string): string {
  if (status === 'mastered') return AppStrings.STATUS_MASTERED;
  if (status === 'reviewing') return AppStrings.STATUS_REVIEWING;
  return AppStrings.STATUS_UNMASTERED;
}

export function statusColor(status: string): string {
  if (status === 'mastered') return AppColors.MASTERY_MASTERED;
  if (status === 'reviewing') return AppColors.MASTERY_REVIEWING;
  return AppColors.MASTERY_UNMASTERED;
}

export function formatDate(timestamp: number): string {
  const d = new Date(timestamp);
  const y = d.getFullYear();
  const m = d.getMonth() + 1;
  const day = d.getDate();
  return `${y}-${m < 10 ? '0' + m : m}-${day < 10 ? '0' + day : day}`;
}

export function generateId(): string {
  return Date.now().toString(36) + Math.random().toString(36).substring(2, 8);
}
