/**
 * 颜色常量（T042/D7）：全部改为 $r 资源引用，调用点 API 不变；
 * 深色模式经 resources/dark/element/color.json 自动适配。
 */
export class AppColors {
  static readonly PRIMARY: Resource = $r('app.color.primary');
  static readonly PRIMARY_LIGHT: Resource = $r('app.color.primary_light');
  static readonly PRIMARY_DARK: Resource = $r('app.color.primary_dark');
  static readonly GRADIENT_START: Resource = $r('app.color.gradient_start');
  static readonly GRADIENT_END: Resource = $r('app.color.gradient_end');
  static readonly SECONDARY: Resource = $r('app.color.secondary');
  static readonly WARNING: Resource = $r('app.color.warning');
  static readonly DANGER: Resource = $r('app.color.danger');
  static readonly SOLID_PRIMARY: Resource = $r('app.color.solid_primary');
  static readonly SOLID_SECONDARY: Resource = $r('app.color.solid_secondary');
  static readonly SOLID_DANGER: Resource = $r('app.color.solid_danger');
  static readonly SOLID_WARNING: Resource = $r('app.color.solid_warning');
  static readonly BG_PAGE: Resource = $r('app.color.bg_page');
  static readonly BG_CARD: Resource = $r('app.color.bg_card');
  static readonly BG_CHIP: Resource = $r('app.color.bg_chip');
  static readonly CHIP_BG: Resource = $r('app.color.chip_bg');
  static readonly ROW_SELECTED: Resource = $r('app.color.row_selected');
  static readonly DISABLED: Resource = $r('app.color.disabled');
  static readonly TEXT_PRIMARY: Resource = $r('app.color.text_primary');
  static readonly TEXT_REGULAR: Resource = $r('app.color.text_regular');
  static readonly TEXT_SECONDARY: Resource = $r('app.color.text_secondary');
  static readonly TEXT_PLACEHOLDER: Resource = $r('app.color.text_placeholder');
  static readonly BORDER: Resource = $r('app.color.border');
  static readonly DIVIDER: Resource = $r('app.color.divider');
  static readonly SHADOW: Resource = $r('app.color.shadow');
  static readonly SHADOW_CARD: Resource = $r('app.color.shadow_card');
  static readonly SHADOW_SOFT: Resource = $r('app.color.shadow_soft');
  static readonly SHADOW_PRIMARY: Resource = $r('app.color.shadow_primary');
  static readonly HERO_TEXT: Resource = $r('app.color.hero_text');
  static readonly HERO_TEXT_DIM: Resource = $r('app.color.hero_text_dim');
  static readonly HERO_BTN_TEXT: Resource = $r('app.color.hero_btn_text');
  static readonly BADGE_BG: Resource = $r('app.color.badge_bg');
  static readonly CROP_MASK: Resource = $r('app.color.crop_mask');
  static readonly IMAGE_VIEWER_BG: Resource = $r('app.color.image_viewer_bg');
  static readonly MASTERY_MASTERED: Resource = $r('app.color.mastery_mastered');
  static readonly MASTERY_REVIEWING: Resource = $r('app.color.mastery_reviewing');
  static readonly MASTERY_UNMASTERED: Resource = $r('app.color.mastery_unmastered');
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
  static readonly PAGE_CAPTURE: string = '录入错题';
  static readonly PAGE_REVIEW: string = '复习错题';
  static readonly PAGE_DETAIL: string = '错题详情';
  static readonly PAGE_DATA: string = '导出与导入';
  static readonly PAGE_REMINDER: string = '复习提醒设置';
  static readonly PAGE_REPORT: string = '学习报告';
  static readonly DELETE: string = '删除';
  static readonly CANCEL: string = '取消';
  static readonly SAVE_SUCCESS: string = '已保存';
  static readonly LOAD_FAILED: string = '加载失败，请检查数据后重试';
  static readonly RETRY: string = '重新加载';
  static readonly NO_MORE_DATA: string = '已加载全部错题';
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

/**
 * 状态/学科标签底色（白字反色场景）：使用 solid_* 深色填充，
 * 保证白字对比度 ≥4.5:1（深色模式经 dark/color.json 单独适配）。
 */
export function statusColor(status: string): Resource {
  if (status === 'mastered') {
    return AppColors.SOLID_SECONDARY;
  }
  if (status === 'reviewing') {
    return AppColors.SOLID_PRIMARY;
  }
  return AppColors.SOLID_DANGER;
}

export function subjectColor(subject: string): Resource {
  if (subject === 'chinese') {
    return AppColors.SOLID_WARNING;
  }
  if (subject === 'english') {
    return AppColors.SOLID_SECONDARY;
  }
  if (subject === 'science') {
    return AppColors.SOLID_PRIMARY;
  }
  return AppColors.SOLID_PRIMARY;
}

export function formatDate(timestamp: number): string {
  const d = new Date(timestamp);
  const y = d.getFullYear();
  const m = d.getMonth() + 1;
  const day = d.getDate();
  return `${y}-${m < 10 ? '0' + m : m}-${day < 10 ? '0' + day : day}`;
}

export function formatDateTime(timestamp: number): string {
  const d = new Date(timestamp);
  const hh = d.getHours();
  const mm = d.getMinutes();
  return `${d.getMonth() + 1}月${d.getDate()}日 ${hh < 10 ? '0' + hh : hh}:${mm < 10 ? '0' + mm : mm}`;
}

/** 标题截断（T047）：统一收敛的文本截断工具。 */
export function truncateText(text: string, maxLen: number): string {
  if (text.length > maxLen) {
    return text.substring(0, maxLen) + '...';
  }
  return text;
}

/**
 * 答案归一化（T035/FR-017）：trim + 小写 + 全角转半角 + 去空格，
 * 判分不受全半角/空格/大小写差异影响。
 */
export function normalizeAnswer(s: string): string {
  if (s.length === 0) {
    return '';
  }
  const lower: string = s.trim().toLowerCase();
  let out: string = '';
  for (let i: number = 0; i < lower.length; i++) {
    const code: number = lower.charCodeAt(i);
    let c: string = lower.charAt(i);
    if (code >= 0xFF01 && code <= 0xFF5E) {
      // 全角 ASCII → 半角
      c = String.fromCharCode(code - 0xFEE0);
    } else if (code === 0x3000) {
      c = ' ';
    }
    out += c;
  }
  return out.replace(new RegExp('\\s+', 'g'), '');
}

/** 归一化答案比较（判分入口）。 */
export function isAnswerEqual(standard: string, student: string): boolean {
  return normalizeAnswer(standard) === normalizeAnswer(student);
}

export function generateId(): string {
  return Date.now().toString(36) + Math.random().toString(36).substring(2, 8);
}

export function toFileUri(path: string): string {
  if (path.startsWith('file://') || path.startsWith('http://') || path.startsWith('https://') ||
    path.startsWith('datashare://') || path.startsWith('content://') || path.startsWith('data:')) {
    return path;
  }
  if (path.length === 0) {
    return path;
  }
  return 'file://' + path;
}
