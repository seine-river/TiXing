import { Subject } from '../models/Enums';

/**
 * 学科自动检测（T035/FR-017）：
 * - 全角括号（（１）（２）等中文题编号）不再计为数学运算符，语文题不再被误判为数学；
 * - 新增科学学科识别（特征词表命中优先于语文兜底）。
 */
export class SubjectDetector {
  private static readonly SCIENCE_KEYWORDS: string[] = [
    '光合', '呼吸作用', '细胞', '植物', '动物', '昆虫', '种子', '根茎叶',
    '溶解', '蒸发', '沸腾', '凝固', '融化', '沉淀', '过滤', '水循环',
    '磁铁', '磁场', '电路', '电流', '电压', '导电', '绝缘',
    '摩擦力', '重力', '浮力', '杠杆', '滑轮', '斜面', '弹簧测力计',
    '温度计', '地球', '月球', '太阳系', '岩石', '土壤', '化石', '生态',
    '声音', '光的反射', '光的折射', '凸透镜', '凹透镜', '实验', '测量'
  ];

  static detect(text: string): Subject {
    let chinese: number = 0;
    let latin: number = 0;
    let digit: number = 0;
    let op: number = 0;
    for (let i: number = 0; i < text.length; i++) {
      const c: number = text.charCodeAt(i);
      if (c >= 0x4e00 && c <= 0x9fff) {
        chinese++;
      } else if ((c >= 65 && c <= 90) || (c >= 97 && c <= 122)) {
        latin++;
      } else if (c >= 48 && c <= 57) {
        digit++;
      } else if (SubjectDetector.isMathOp(c)) {
        op++;
      }
    }
    // 数学：需同时出现数字与半角运算符（全角括号编号不构成数学特征）
    if (digit >= 1 && op >= 1) {
      return Subject.MATH;
    }
    if (digit >= 3 && latin === 0) {
      return Subject.MATH;
    }
    if (latin > chinese && latin >= 2) {
      return Subject.ENGLISH;
    }
    // 科学：中文文本命中特征词
    if (chinese > 0 && SubjectDetector.hasScienceKeyword(text)) {
      return Subject.SCIENCE;
    }
    if (chinese === 0 && latin === 0 && digit === 0) {
      return Subject.MATH;
    }
    return Subject.CHINESE;
  }

  private static hasScienceKeyword(text: string): boolean {
    for (const kw of SubjectDetector.SCIENCE_KEYWORDS) {
      if (text.indexOf(kw) >= 0) {
        return true;
      }
    }
    return false;
  }

  private static isMathOp(c: number): boolean {
    // 注意：不含全角括号 65288/65289（（），中文题编号常用，不再视为运算符）
    return c === 43 || c === 45 || c === 42 || c === 47 || c === 61 ||
      c === 60 || c === 62 || c === 37 || c === 94 || c === 40 || c === 41 ||
      c === 215 || c === 247 || c === 8730 || c === 8804 || c === 8805;
  }
}
