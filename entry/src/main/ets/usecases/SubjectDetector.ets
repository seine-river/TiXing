import { Subject } from '../models/Enums';

export class SubjectDetector {
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
    if (digit >= 1 && op >= 1) {
      return Subject.MATH;
    }
    if (digit >= 3 && latin === 0) {
      return Subject.MATH;
    }
    if (latin > chinese && latin >= 2) {
      return Subject.ENGLISH;
    }
    if (chinese === 0 && latin === 0 && digit === 0) {
      return Subject.MATH;
    }
    return Subject.CHINESE;
  }

  private static isMathOp(c: number): boolean {
    return c === 43 || c === 45 || c === 42 || c === 47 || c === 61 ||
      c === 60 || c === 62 || c === 37 || c === 94 || c === 40 || c === 41 ||
      c === 215 || c === 247 || c === 8730 || c === 8804 || c === 8805 ||
      c === 65288 || c === 65289;
  }
}
