/**
 * 从大模型输出中稳健提取 JSON。
 *
 * 模型偶发返回：
 * - JSON 前后带解释文字；
 * - 一个回复里出现多个 JSON 对象；
 * - 字符串内含未转义换行；
 * - 数组或对象末尾多一个逗号。
 * 这些情况会让 ArkTS 的 JSON.parse 报 “Unexpected Object in JSON”。
 */
export class JsonExtractor {
  /**
   * 返回文本中所有顶层 JSON 值（对象或数组），已正确跳过字符串内的括号。
   */
  static candidates(raw: string): string[] {
    const result: string[] = [];
    let inString: boolean = false;
    let escaped: boolean = false;
    let depth: number = 0;
    let start: number = -1;
    for (let i: number = 0; i < raw.length; i++) {
      const ch: string = raw.charAt(i);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch === '\\') {
          escaped = true;
        } else if (ch === '"') {
          inString = false;
        }
        continue;
      }
      if (ch === '"') {
        inString = true;
        continue;
      }
      if (ch === '{' || ch === '[') {
        if (depth === 0) {
          start = i;
        }
        depth++;
        continue;
      }
      if (ch === '}' || ch === ']') {
        if (depth > 0) {
          depth--;
          if (depth === 0 && start >= 0) {
            result.push(raw.substring(start, i + 1));
            start = -1;
          }
        }
      }
    }
    return result;
  }

  /**
   * 兼容旧调用：优先返回最长的顶层 JSON，避免把前后说明文字一起交给 JSON.parse。
   */
  static first(raw: string): string {
    const list: string[] = JsonExtractor.candidates(raw);
    if (list.length === 0) {
      return raw;
    }
    let best: string = list[0];
    for (let i: number = 1; i < list.length; i++) {
      if (list[i].length > best.length) {
        best = list[i];
      }
    }
    return best;
  }

  /**
   * 把字符串内部未转义的换行、制表符等控制字符转成合法 JSON 转义。
   */
  static normalizeControlCharacters(json: string): string {
    let output: string = '';
    let inString: boolean = false;
    let escaped: boolean = false;
    for (let i: number = 0; i < json.length; i++) {
      const ch: string = json.charAt(i);
      if (inString) {
        if (escaped) {
          output += ch;
          escaped = false;
          continue;
        }
        if (ch === '\\') {
          output += ch;
          escaped = true;
          continue;
        }
        if (ch === '"') {
          inString = false;
          output += ch;
          continue;
        }
        const code: number = ch.charCodeAt(0);
        if (code < 0x20) {
          if (ch === '\n') {
            output += '\\n';
          } else if (ch === '\r') {
            output += '\\r';
          } else if (ch === '\t') {
            output += '\\t';
          } else {
            output += ' ';
          }
        } else {
          output += ch;
        }
        continue;
      }
      if (ch === '"') {
        inString = true;
      }
      output += ch;
    }
    return output;
  }

  static removeTrailingCommas(json: string): string {
    return json.replace(/,\s*([}\]])/g, '$1');
  }

  /**
   * 修复模型偶发输出的 JavaScript 风格对象：{title:"...", scenes:[]}。
   * 只在标准 JSON 解析失败后作为兜底候选使用。
   */
  static quoteUnquotedKeys(json: string): string {
    return json.replace(/([{,]\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:/g, '$1"$2":');
  }

  /**
   * 修复讲解脚本中偶发的 screen 对象未闭合：
   * "screen":{...,"visual":{...},"animation":"..."}
   * animation 本应与 screen 同级，这里在 visual 后补上 screen 的右括号。
   */
  static closeScreenBeforeAnimation(json: string): string {
    return json.replace(
      /("screen"\s*:\s*\{[^{}]*"visual"\s*:\s*\{[^{}]*\})\s*,\s*"animation"\s*:/g,
      '$1}, "animation":');
  }
}
