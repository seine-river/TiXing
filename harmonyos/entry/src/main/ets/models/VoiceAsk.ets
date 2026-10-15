import { generateId } from '../common/Constants';

/**
 * 语音问答是独立于错题本的学习痕迹：
 * 原始音频长期保留，AI 只负责转写、回答与分类归档。
 */
export class VoiceAskRecord {
  id: string = generateId();
  studentId: string = 'stu_default';
  questionText: string = '';
  answerText: string = '';
  subject: string = 'other';
  topic: string = '';
  interestTags: string[] = [];
  questionType: string = 'fact';
  gradeLevel: string = '';
  audioPath: string = '';
  audioDuration: number = 0;
  asrStatus: string = 'pending';
  aiStatus: string = 'pending';
  safetyLevel: string = 'normal';
  status: string = 'active';
  createdAt: number = Date.now();
  updatedAt: number = Date.now();

  static create(studentId: string, grade: string, audioPath: string,
    audioDuration: number): VoiceAskRecord {
    const record = new VoiceAskRecord();
    record.studentId = studentId;
    record.gradeLevel = grade;
    record.audioPath = audioPath;
    record.audioDuration = audioDuration;
    return record;
  }
}

export class InterestInsight {
  id: string = generateId();
  studentId: string = 'stu_default';
  periodStart: number = 0;
  periodEnd: number = 0;
  questionCount: number = 0;
  topSubjects: string[] = [];
  topTopics: string[] = [];
  interestTags: string[] = [];
  trend: string = 'stable';
  childSummary: string = '';
  parentSummary: string = '';
  recommendedActivities: string[] = [];
  generatedAt: number = Date.now();
}

export class VoiceAskSubjectSummary {
  subject: string = '';
  count: number = 0;
}

export class VoiceAskTopicSummary {
  topic: string = '';
  count: number = 0;
}

export class VoiceAskTagSummary {
  tag: string = '';
  count: number = 0;
}

export class VoiceAskStats {
  total: number = 0;
  weekCount: number = 0;
  subjects: VoiceAskSubjectSummary[] = [];
  topics: VoiceAskTopicSummary[] = [];
  tags: VoiceAskTagSummary[] = [];
}

export function voiceAskSubjectLabel(subject: string): string {
  if (subject === 'math') {
    return '数学';
  }
  if (subject === 'chinese') {
    return '语文';
  }
  if (subject === 'english') {
    return '英语';
  }
  if (subject === 'science') {
    return '科学';
  }
  if (subject === 'history') {
    return '历史';
  }
  if (subject === 'geography') {
    return '地理';
  }
  if (subject === 'technology') {
    return '科技';
  }
  if (subject === 'life') {
    return '生活';
  }
  if (subject === 'art') {
    return '艺术';
  }
  if (subject === 'sports') {
    return '运动';
  }
  return '其他';
}

export function voiceAskQuestionTypeLabel(type: string): string {
  if (type === 'reason') {
    return '爱问为什么';
  }
  if (type === 'compare') {
    return '喜欢比较';
  }
  if (type === 'imagine') {
    return '大胆想象';
  }
  if (type === 'how_to') {
    return '动手实践';
  }
  if (type === 'help') {
    return '求助';
  }
  return '事实探索';
}

export function voiceAskSafetyLabel(level: string): string {
  if (level === 'attention') {
    return '建议家长关注';
  }
  return '安全';
}
