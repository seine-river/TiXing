/**
 * 轻量操作结果类型（统一错误处理 D2）。
 * 所有数据库写操作返回 DbResult，失败时携带 op 与 reason，不再静默吞错。
 */
export class DbResult {
  readonly success: boolean = true;
  readonly op: string = '';
  readonly reason: string = '';

  private constructor(success: boolean, op: string, reason: string) {
    this.success = success;
    this.op = op;
    this.reason = reason;
  }

  static ok(): DbResult {
    return new DbResult(true, '', '');
  }

  static fail(op: string, reason: string): DbResult {
    return new DbResult(false, op, reason);
  }
}
