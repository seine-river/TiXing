export class AppContextHolder {
  private static _context: Context | undefined = undefined;

  static set(context: Context): void {
    AppContextHolder._context = context;
  }

  static get(): Context | undefined {
    return AppContextHolder._context;
  }

  static require(): Context {
    const c = AppContextHolder._context;
    if (c === undefined) {
      throw new Error('AppContext not initialized');
    }
    return c;
  }
}
