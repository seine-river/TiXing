import {
  Subject, ErrorType, MistakeStatus, AnswerType, SyncStatus, ContentType
} from './Enums';

export class Mistake {
  id: string = '';
  studentId: string = '';
  imageUrl: string = '';
  ocrText: string = '';
  ocrConfidence: number = 0;
  isConfirmed: boolean = false;
  subject: Subject = Subject.MATH;
  knowledgeTagIds: string[] = [];
  errorType: ErrorType = ErrorType.OTHER;
  status: MistakeStatus = MistakeStatus.UNMASTERED;
  intervalIndex: number = 0;
  nextReviewDate: number = 0;
  firstReviewDuration: number = 0;
  standardAnswer: string = '';
  studentAnswer: string = '';
  knowledgeSummary: string = '';
  answerType: AnswerType = AnswerType.TEXT;
  notes: string = '';
  notesAttachmentUrl: string = '';
  sharedToCommunity: boolean = false;
  communityPostId: string = '';
  createdAt: number = 0;
  syncStatus: SyncStatus = SyncStatus.SYNCED;

  static create(
    id: string,
    studentId: string,
    imageUrl: string,
    ocrText: string,
    subject: Subject,
    knowledgeTagIds: string[],
    answerType: AnswerType,
    standardAnswer: string
  ): Mistake {
    const m = new Mistake();
    m.id = id;
    m.studentId = studentId;
    m.imageUrl = imageUrl;
    m.ocrText = ocrText;
    m.subject = subject;
    m.knowledgeTagIds = knowledgeTagIds;
    m.answerType = answerType;
    m.standardAnswer = standardAnswer;
    m.createdAt = Date.now();
    m.nextReviewDate = Date.now() + 24 * 60 * 60 * 1000;
    m.syncStatus = SyncStatus.PENDING;
    return m;
  }
}

export class OcrFieldResult {
  text: string = '';
  confidence: number = 0;
  contentType: ContentType = ContentType.PRINTED_TEXT;

  constructor(text: string, confidence: number, contentType: ContentType) {
    this.text = text;
    this.confidence = confidence;
    this.contentType = contentType;
  }
}

export class OcrRecognitionResult {
  questionText: OcrFieldResult = new OcrFieldResult('', 0, ContentType.PRINTED_TEXT);
  studentAnswerText: OcrFieldResult = new OcrFieldResult('', 0, ContentType.PRINTED_TEXT);
  standardAnswerCandidate: OcrFieldResult = new OcrFieldResult('', 0, ContentType.PRINTED_TEXT);
  contentType: ContentType = ContentType.PRINTED_TEXT;
}

export class ImageRegion {
  x: number = 0;
  y: number = 0;
  width: number = 0;
  height: number = 0;

  constructor(x: number, y: number, width: number, height: number) {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
  }
}

export class CropFracs {
  leftFrac: number = 0;
  topFrac: number = 0;
  rightFrac: number = 1;
  bottomFrac: number = 1;

  constructor(leftFrac: number, topFrac: number, rightFrac: number, bottomFrac: number) {
    this.leftFrac = leftFrac;
    this.topFrac = topFrac;
    this.rightFrac = rightFrac;
    this.bottomFrac = bottomFrac;
  }
}

export class ImageQualityResult {
  passed: boolean = false;
  issue: string = '';

  static ok(): ImageQualityResult {
    const r = new ImageQualityResult();
    r.passed = true;
    return r;
  }

  static fail(issue: string): ImageQualityResult {
    const r = new ImageQualityResult();
    r.passed = false;
    r.issue = issue;
    return r;
  }
}
