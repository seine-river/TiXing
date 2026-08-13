export class AnalyticsEvent {
  id: string = '';
  eventType: string = '';
  studentIdHash: string = '';
  platform: string = 'harmonyos';
  properties: string = '';
  occurredAt: number = 0;

  static create(id: string, eventType: string, studentId: string, properties: string): AnalyticsEvent {
    const e = new AnalyticsEvent();
    e.id = id;
    e.eventType = eventType;
    e.studentIdHash = hashStudentId(studentId);
    e.properties = properties;
    e.occurredAt = Date.now();
    return e;
  }
}

export class MetricSummary {
  captureCount: number = 0;
  reviewSubmitCount: number = 0;
  masteryAchievedCount: number = 0;
  ocrConfirmCount: number = 0;
  avgOcrConfidence: number = 0;
  reviewAccuracy: number = 0;
}

function hashStudentId(studentId: string): string {
  let hash: number = 0;
  for (let i = 0; i < studentId.length; i++) {
    const ch: number = studentId.charCodeAt(i);
    hash = ((hash << 5) - hash) + ch;
    hash = hash & hash;
  }
  return 'h_' + Math.abs(hash).toString(36);
}
