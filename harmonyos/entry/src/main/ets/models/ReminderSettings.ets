export class ReminderSettings {
  id: string = 'default';
  studentId: string = '';
  reviewTimeStart: string = '08:00';
  reviewTimeEnd: string = '21:00';
  dailyLimit: number = 10;
  mathEnabled: boolean = true;
  chineseEnabled: boolean = true;
  englishEnabled: boolean = false;
  scienceEnabled: boolean = false;
  doNotDisturb: boolean = false;
  notificationEnabled: boolean = true;
  updatedAt: number = 0;

  static create(studentId: string): ReminderSettings {
    const r = new ReminderSettings();
    r.studentId = studentId;
    r.updatedAt = Date.now();
    return r;
  }
}
