import http from '@ohos.net.http';
import util from '@ohos.util';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Subject, AnswerType, ErrorType } from '../models/Enums';
import { MediaService } from './MediaService';
import { AiConfig } from '../common/AiConfig';
import { VoiceAskRecord } from '../models/VoiceAsk';

const CONFIG_GUIDE: string =
  'AI 未配置：请在 entry/src/main/resources/rawfile/apiconfig.json 中配置 apiKey';
const BODY_SUMMARY_MAX: number = 160;
const LOG_BODY_MAX: number = 8000;
const LOG_CHUNK_MAX: number = 800;
const LOG_DOMAIN: number = 0xA004;
const LOG_TAG: string = 'TiXingAiService';

interface AiImageUrl {
  url: string;
}

interface AiContentPart {
  type: string;
  text?: string;
  image_url?: AiImageUrl;
}

interface AiMessage {
  role: string;
  content: AiContentPart[];
}

interface AiResponseMessage {
  content?: string;
  reasoning_content?: string;
}

interface AiResponseChoice {
  message: AiResponseMessage;
  finish_reason?: string;
}

interface AiResponse {
  choices: AiResponseChoice[];
  usage?: AiResponseUsage;
}

interface AiResponseUsage {
  prompt_tokens?: number;
  completion_tokens?: number;
  total_tokens?: number;
}

interface AiThinking {
  type: string;
  clear_thinking?: boolean;
}

const THINKING_ENABLED: string = 'enabled';
const REASONING_EFFORT_LOW: string = 'low';

interface AiAnalysisRaw {
  analysis: string;
  answerType: string;
  subject: string;
  knowledgeTags: string[];
}

interface AiQuestionRaw {
  question?: string;
  title?: string;
  myAnswer?: string;
  myAnswerPresent?: boolean;
  standardAnswer?: string;
  knowledgeSummary?: string;
  subject?: string;
  answerType?: string;
  errorType?: string;
  knowledgeTags?: string[];
  tags?: string[];
}

interface AiQuestionListRaw {
  questionCount?: number;
  questions?: AiQuestionRaw[];
  items?: AiQuestionRaw[];
}

interface AiAnswerRetryRaw {
  myAnswer?: string;
  myAnswerPresent?: boolean;
}

interface AiLessonScreenRaw {
  type?: string;
  title?: string;
  text?: string;
  highlight?: string;
  steps?: string[];
  studentAnswer?: string;
  standardAnswer?: string;
  visual?: AiLessonVisualRaw;
}

interface AiLessonVisualRaw {
  type?: string;
  labels?: string[];
  numerators?: number[];
  denominators?: number[];
  resultNumerator?: number;
  resultDenominator?: number;
  nodes?: string[];
  icons?: string[];
  captions?: string[];
  highlightIndex?: number;
}

interface AiLessonSceneRaw {
  id?: string;
  duration?: number;
  narration?: string;
  subtitle?: string;
  screen?: AiLessonScreenRaw;
  animation?: string;
}

interface AiLessonRaw {
  title?: string;
  totalDuration?: number;
  gradeLevel?: string;
  tone?: string;
  scenes?: AiLessonSceneRaw[];
}

interface AiApiErrorBody {
  code?: number | string;
  message?: string;
}

interface AiVoiceAnswerRaw {
  answerText?: string;
  subject?: string;
  topic?: string;
  interestTags?: string[];
  questionType?: string;
  safetyLevel?: string;
  followUpQuestion?: string;
}

interface AiCuriosityRaw {
  childSummary?: string;
  parentSummary?: string;
  recommendedActivities?: string[];
  trend?: string;
}

export class AiAnalysis {
  analysis: string = '';
  answerType: AnswerType = AnswerType.TEXT;
  subject: Subject = Subject.MATH;
  tags: string[] = [];
  error: string = '';
}

export class AiServiceError extends Error {
  readonly diagnostic: string = '';

  constructor(message: string, diagnostic: string) {
    super(message);
    this.diagnostic = diagnostic;
  }
}

export class AiQuestionResult {
  question: string = '';
  myAnswer: string = '';
  myAnswerPresent: boolean = false;
  standardAnswer: string = '';
  knowledgeSummary: string = '';
  subject: Subject = Subject.MATH;
  answerType: AnswerType = AnswerType.TEXT;
  errorType: ErrorType = ErrorType.OTHER;
  tags: string[] = [];
  ok: boolean = false;
  error: string = '';
}

export class AiQuestionBatch {
  items: AiQuestionResult[] = [];
  ok: boolean = false;
  error: string = '';
}

export class AiVoiceAnswer {
  answerText: string = '';
  subject: string = 'other';
  topic: string = '';
  interestTags: string[] = [];
  questionType: string = 'fact';
  safetyLevel: string = 'normal';
  followUpQuestion: string = '';
}

export class AiCuriosityReport {
  childSummary: string = '';
  parentSummary: string = '';
  recommendedActivities: string[] = [];
  trend: string = 'stable';
}

export class AiLessonScreen {
  type: string = 'text';
  title: string = '';
  text: string = '';
  highlight: string = '';
  steps: string[] = [];
  studentAnswer: string = '';
  standardAnswer: string = '';
  visual: AiLessonVisual = new AiLessonVisual();
}

export class AiLessonVisual {
  type: string = '';
  labels: string[] = [];
  numerators: number[] = [];
  denominators: number[] = [];
  resultNumerator: number = 0;
  resultDenominator: number = 0;
  nodes: string[] = [];
  icons: string[] = [];
  captions: string[] = [];
  highlightIndex: number = 0;
}

export class AiLessonScene {
  id: string = '';
  duration: number = 8;
  narration: string = '';
  subtitle: string = '';
  screen: AiLessonScreen = new AiLessonScreen();
  animation: string = '';
}

export class AiLesson {
  title: string = '错题讲解';
  totalDuration: number = 0;
  gradeLevel: string = '';
  tone: string = '亲切、鼓励、适合小学生';
  scenes: AiLessonScene[] = [];
  error: string = '';
}

export class AiService {
  private static async ensureConfig(): Promise<void> {
    await AiConfig.load();
    if (!AiConfig.configured) {
      throw new Error(CONFIG_GUIDE);
    }
  }

  static async answerVoiceQuestion(question: string, grade: string): Promise<AiVoiceAnswer> {
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'voice answer start: questionLength=%{public}d, grade=%{public}s, model=%{public}s',
      question.length, grade, AiConfig.model);
    const prompt: string =
      '你是一个叫醒醒的儿童学习伙伴，回答小学生通过语音提出的问题。请语气亲切、鼓励、简明，符合给定年级；' +
      '如果问题不完整，请合理补全；如果涉及危险、隐私、身体健康或情绪困扰，要温和建议请家长一起处理。\n' +
      `学生年级：${grade}\n问题：${question}\n` +
      '请只返回纯JSON，不要markdown代码块：' +
      '{"answerText":"给孩子的回答，120-220字","subject":"math/chinese/english/science/history/geography/technology/life/art/sports/other",' +
      '"topic":"8字以内主题","interestTags":["兴趣标签1","兴趣标签2"],"questionType":"fact/reason/compare/imagine/how_to/help",' +
      '"safetyLevel":"normal/attention","followUpQuestion":"一个适合孩子继续思考的问题"}。字段名必须使用英文。';
    const raw: string = await AiService.request([{ role: 'user', content: [{ type: 'text', text: prompt }] }]);
    try {
      const obj: AiVoiceAnswerRaw = JSON.parse(AiService.extractJson(raw)) as AiVoiceAnswerRaw;
      const result: AiVoiceAnswer = new AiVoiceAnswer();
      result.answerText = obj.answerText !== undefined ? obj.answerText.trim() : '';
      result.subject = AiService.normalizeVoiceSubject(obj.subject);
      result.topic = obj.topic !== undefined ? obj.topic.trim() : '';
      result.interestTags = obj.interestTags !== undefined ? obj.interestTags : [];
      result.questionType = AiService.normalizeVoiceQuestionType(obj.questionType);
      result.safetyLevel = obj.safetyLevel === 'attention' ? 'attention' : 'normal';
      result.followUpQuestion = obj.followUpQuestion !== undefined ? obj.followUpQuestion.trim() : '';
      if (result.answerText.length === 0) {
        throw new Error('缺少 answerText 字段');
      }
      if (result.interestTags.length === 0 && result.topic.length > 0) {
        result.interestTags.push(result.topic);
      }
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'voice answer parsed: answerLength=%{public}d, subject=%{public}s, topic=%{public}s',
        result.answerText.length, result.subject, result.topic);
      return result;
    } catch (e) {
      const diagnostic: string = `voice answer JSON parse failed: ${AiService.errorDetail(e)}\nraw=${AiService.logBody(raw)}`;
      AiService.logLongError('voice answer parse', diagnostic);
      throw new AiServiceError('AI 回答格式异常，请重试', diagnostic);
    }
  }

  static async generateCuriosityReport(records: VoiceAskRecord[], grade: string): Promise<AiCuriosityReport> {
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'curiosity report start: questionCount=%{public}d, grade=%{public}s',
      records.length, grade);
    const lines: string[] = [];
    const maxCount: number = Math.min(records.length, 100);
    for (let i: number = 0; i < maxCount; i++) {
      const record: VoiceAskRecord = records[i];
      lines.push(`${i + 1}. ${record.questionText} | subject=${record.subject} | topic=${record.topic}`);
    }
    const prompt: string =
      '请根据小学生的历史提问生成“好奇星球”兴趣报告。孩子视角要有趣、正向、具体；家长视角要冷静、可操作，不做负面评价。\n' +
      `学生年级：${grade}\n提问数量：${records.length}\n最近提问：\n${lines.join('\n')}\n` +
      '只返回纯JSON：{"childSummary":"给孩子看的趣味总结，80-150字","parentSummary":"给家长看的观察和建议，100-180字",' +
      '"recommendedActivities":["活动建议1","活动建议2","活动建议3"],"trend":"rising/stable/cooling"}。字段名必须使用英文。';
    const raw: string = await AiService.request([{ role: 'user', content: [{ type: 'text', text: prompt }] }],
      4096, 'low');
    try {
      const obj: AiCuriosityRaw = JSON.parse(AiService.extractJson(raw)) as AiCuriosityRaw;
      const report: AiCuriosityReport = new AiCuriosityReport();
      report.childSummary = obj.childSummary !== undefined ? obj.childSummary.trim() : '';
      report.parentSummary = obj.parentSummary !== undefined ? obj.parentSummary.trim() : '';
      report.recommendedActivities = obj.recommendedActivities !== undefined ? obj.recommendedActivities : [];
      report.trend = obj.trend === 'rising' || obj.trend === 'cooling' ? obj.trend : 'stable';
      if (report.childSummary.length === 0 || report.parentSummary.length === 0) {
        throw new Error('缺少总结字段');
      }
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'curiosity report parsed: childLength=%{public}d, parentLength=%{public}d',
        report.childSummary.length, report.parentSummary.length);
      return report;
    } catch (e) {
      const diagnostic: string =
        `curiosity report JSON parse failed: ${AiService.errorDetail(e)}\nraw=${AiService.logBody(raw)}`;
      AiService.logLongError('curiosity report parse', diagnostic);
      throw new AiServiceError('好奇星球报告生成失败，请重试', diagnostic);
    }
  }

  static async recognizeImage(imagePath: string): Promise<string> {
    let base64: string | undefined;
    try {
      base64 = await MediaService.readImageBase64(imagePath, 1800);
    } catch (e) {
      AiService.logError('read image for recognizeImage', e);
      throw new Error('图片读取异常，请重新选择图片');
    }
    if (base64 === undefined || base64.length === 0) {
      hilog.error(LOG_DOMAIN, LOG_TAG,
        'read image for recognizeImage failed: path=%{public}s, base64Length=%{public}d',
        imagePath, base64 === undefined ? -1 : base64.length);
      throw new Error('图片读取失败，请重新选择图片');
    }
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'recognizeImage image ready: base64Length=%{public}d', base64.length);
    const part1: AiContentPart = {
      type: 'image_url',
      image_url: { url: 'data:image/jpeg;base64,' + base64 }
    };
    const part2: AiContentPart = {
      type: 'text',
      text: '请识别图片中所有可见文字，包括多道题目的题号、题干、选项和学生手写作答。按人类阅读顺序原样输出，不要总结、不要解释。'
    };
    const msg: AiMessage = { role: 'user', content: [part1, part2] };
    return AiService.request([msg]);
  }

  static async recognizeQuestion(imagePath: string): Promise<AiQuestionResult> {
    const batch: AiQuestionBatch = await AiService.recognizeQuestions(imagePath);
    if (batch.items.length > 0) {
      return batch.items[0];
    }
    const result: AiQuestionResult = new AiQuestionResult();
    result.error = batch.error.length > 0 ? batch.error : 'AI 未能识别出题目';
    return result;
  }

  /**
   * 多题识别：一张作业/试卷照片中可能只有一道题，也可能包含多道题。
   * GLM 按题号拆分题目和对应学生答案，供录入页让用户选择要保存的那一道。
   */
  static async recognizeQuestions(imagePath: string): Promise<AiQuestionBatch> {
    let base64: string | undefined;
    try {
      base64 = await MediaService.readImageBase64(imagePath, 1800);
    } catch (e) {
      AiService.logError('read image for recognizeQuestions', e);
      throw new Error('图片读取异常，请重新选择图片');
    }
    if (base64 === undefined || base64.length === 0) {
      hilog.error(LOG_DOMAIN, LOG_TAG,
        'read image for recognizeQuestions failed: path=%{public}s, base64Length=%{public}d',
        imagePath, base64 === undefined ? -1 : base64.length);
      throw new Error('图片读取失败，请重新选择图片');
    }
    const textPrompt: string =
      '这是一张小学生作业或试卷照片，可能只有一道题，也可能包含多道题，还包含学生手写作答和批改痕迹。请仔细看图，按题号把每道题拆开识别，并以纯JSON返回，不要markdown代码块和解释。\n' +
      '返回格式：{"questionCount":题目数量,"questions":[{"question":"这一道题的完整题干，保留题号、共用材料和选项","myAnswer":"这一道题对应的学生作答，没有则为空字符串","myAnswerPresent":true或false,"standardAnswer":"这一道题可见的正确答案或批改结果，看不出则为空字符串","knowledgeSummary":"不超过10个汉字的知识点名称","subject":"math或chinese或english或science","answerType":"choice或numeric或text或subjective","errorType":"concept或careless或misread或other","knowledgeTags":["标签1","标签2"]}]}\n' +
      '多题拆分要求：必须按可见题号、题目间距或版式把图片拆成多道题；每道题只归属自己下方或旁边的学生答案；如果多道小题共享阅读材料或题干，每道题的question都要带上必要的共用材料；不要把多道题合并成一个长字符串；只有确实看不出任何题目时questions才返回空数组。\n' +
      '学生答案识别要求：小学生答案通常写在题目下方、横线上、括号内或题目留白处，笔迹常与印刷题干不同，可能是铅笔、圆珠笔或歪斜手写体。myAnswer必须原样转写学生写的算式、字母、汉字、选项和结果，不要混入题干、教师批注或标准答案。只有确认该题没有学生作答痕迹时，myAnswer才为空并把myAnswerPresent设为false；只要看得到作答痕迹，即使不完整也要转写并把myAnswerPresent设为true。\n' +
      '其他要求：questionCount必须等于questions长度；JSON字段名必须完全使用英文；subject只能是math/chinese/english/science；answerType只能是choice/numeric/text/subjective；errorType只能是concept/careless/misread/other；knowledgeTags每题2-4个简短标签。只输出JSON。';
    const parts: AiContentPart[] = [
      { type: 'image_url', image_url: { url: 'data:image/jpeg;base64,' + base64 } },
      { type: 'text', text: textPrompt }
    ];
    const raw: string = await AiService.request([{ role: 'user', content: parts }]);
    const batch: AiQuestionBatch = AiService.parseQuestions(raw);
    if (!batch.ok) {
      hilog.error(LOG_DOMAIN, LOG_TAG,
        'recognizeQuestions parse failed: error=%{public}s, raw=%{public}s',
        batch.error, AiService.logBody(raw));
      return AiService.fallbackRecognizeQuestions(imagePath, batch);
    }
    return batch;
  }

  /**
   * AI 全图识别（无本地 OCR 环节）：直接把整张错题照片交给多模态模型，
   * 一次性提取题目、我的答案、标准答案、学科、题型、错误类型与知识点。
   */
  private static async recognizeQuestionLegacy(imagePath: string): Promise<AiQuestionResult> {
    let base64: string | undefined;
    try {
      base64 = await MediaService.readImageBase64(imagePath, 1280);
    } catch (e) {
      AiService.logError('read image for recognizeQuestion', e);
      throw new Error('图片读取异常，请重新选择图片');
    }
    if (base64 === undefined || base64.length === 0) {
      hilog.error(LOG_DOMAIN, LOG_TAG,
        'read image for recognizeQuestion failed: path=%{public}s, base64Length=%{public}d',
        imagePath, base64 === undefined ? -1 : base64.length);
      throw new Error('图片读取失败，请重新选择图片');
    }
    const textPrompt: string =
      '这是一道小学生错题的照片（可能包含题目、学生作答和批改痕迹）。请仔细看图，并以纯JSON返回（不要markdown代码块、不要解释）。\n' +
      '返回格式：{"question":"图中的完整题目内容，保留原有题号与选项","myAnswer":"图中学生的作答内容，没有则为空字符串","myAnswerPresent":true或false,"standardAnswer":"图中可见的正确答案或批改结果，看不出则为空字符串","knowledgeSummary":"不超过10个汉字的知识点名称","subject":"math或chinese或english或science","answerType":"choice或numeric或text或subjective","errorType":"concept或careless或misread或other","knowledgeTags":["标签1","标签2"]}\n' +
      '学生答案识别要求：小学生答案通常写在题目下方、横线上、括号内或题目留白处，笔迹常与印刷题干不同，可能是铅笔、圆珠笔或歪斜手写体。请先定位完整题目，再重点检查题目正下方和答题空白区域；myAnswer 必须原样转写学生写的算式、字母、汉字、选项和结果，不要混入题干、教师批注或标准答案。只有确认照片中没有学生作答痕迹时，myAnswer 才能为空字符串并把 myAnswerPresent 设为 false；只要看得到作答痕迹，即使不完整也要转写并把 myAnswerPresent 设为 true。\n' +
      '其他要求：JSON字段名必须完全使用上方英文单词，不要翻译字段名；subject 只能是 math/chinese/english/science；answerType 只能是 choice/numeric/text/subjective；errorType 只能是 concept/careless/misread/other；knowledgeTags 2-4个简短标签。只输出JSON。';
    const parts: AiContentPart[] = [
      { type: 'image_url', image_url: { url: 'data:image/jpeg;base64,' + base64 } },
      { type: 'text', text: textPrompt }
    ];
    const raw: string = await AiService.request([{ role: 'user', content: parts }]);
    const result: AiQuestionResult = AiService.parseQuestion(raw);
    if (!result.ok) {
      hilog.error(LOG_DOMAIN, LOG_TAG,
        'recognizeQuestion parse failed: error=%{public}s, raw=%{public}s',
        result.error, AiService.logBody(raw));
      return AiService.fallbackRecognizeQuestion(imagePath, result);
    }
    if (AiService.shouldRetryStudentAnswer(result)) {
      return AiService.fillStudentAnswer(imagePath, result);
    }
    return result;
  }

  /**
   * 结构化识别失败时的兜底：错题详情页的纯文本识别链路已验证可用，
   * 因此再按“原图转文字”识别一次，把文字直接作为题目内容，保证录入不被
   * JSON 字段名/格式的小差异卡住。
   */
  private static async fallbackRecognizeQuestion(imagePath: string,
    structured: AiQuestionResult): Promise<AiQuestionResult> {
    try {
      const text: string = await AiService.recognizeImage(imagePath);
      const cleaned: string = AiService.plainQuestionText(text);
      if (cleaned.length > 0) {
        structured.question = cleaned;
        structured.ok = true;
        structured.error = '';
        hilog.info(LOG_DOMAIN, LOG_TAG,
          'recognizeQuestion fallback succeeded: textLength=%{public}d', cleaned.length);
      }
    } catch (e) {
      AiService.logError('recognizeQuestion fallback', e);
    }
    if (structured.ok && AiService.shouldRetryStudentAnswer(structured)) {
      return AiService.fillStudentAnswer(imagePath, structured);
    }
    return structured;
  }

  private static async fallbackRecognizeQuestions(imagePath: string,
    batch: AiQuestionBatch): Promise<AiQuestionBatch> {
    try {
      const text: string = await AiService.recognizeImage(imagePath);
      const cleaned: string = AiService.plainQuestionText(text);
      if (cleaned.length > 0) {
        batch.items = AiService.parsePlainQuestions(cleaned);
        batch.ok = true;
        batch.error = '';
        hilog.info(LOG_DOMAIN, LOG_TAG,
          'recognizeQuestions fallback succeeded: textLength=%{public}d, questionCount=%{public}d',
          cleaned.length, batch.items.length);
      }
    } catch (e) {
      AiService.logError('recognizeQuestions fallback', e);
    }
    return batch;
  }

  /**
   * 首次结构化识别没有拿到学生答案时，用更聚焦的视觉提示再识别一次。
   * 如果模型已明确判断照片中没有学生作答，则不额外请求。
   */
  private static shouldRetryStudentAnswer(result: AiQuestionResult): boolean {
    return result.myAnswer.length === 0 && !result.myAnswerPresent;
  }

  private static async fillStudentAnswer(imagePath: string,
    result: AiQuestionResult): Promise<AiQuestionResult> {
    let base64: string | undefined;
    try {
      base64 = await MediaService.readImageBase64(imagePath, 1280);
    } catch (e) {
      AiService.logError('read image for student answer retry', e);
      return result;
    }
    if (base64 === undefined || base64.length === 0) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'student answer retry image empty');
      return result;
    }

    const prompt: string =
      '请在这张小学生错题照片中只寻找学生的作答内容。学生答案通常在题目下方、横线上、括号内或题目留白处，手写笔迹可能与印刷题干不同。请重点看完整题目正下方的区域，原样转写学生写的算式、字母、汉字、选项和结果；不要输出题干、教师批注或标准答案。\n' +
      '以纯JSON返回，不要markdown代码块和解释：{"myAnswer":"学生作答内容，没有则为空字符串","myAnswerPresent":true或false}。字段名必须使用英文。';
    const imagePart: AiContentPart = {
      type: 'image_url',
      image_url: { url: 'data:image/jpeg;base64,' + base64 }
    };
    const textPart: AiContentPart = { type: 'text', text: prompt };
    try {
      const raw: string = await AiService.request([{ role: 'user', content: [imagePart, textPart] }]);
      const jsonStr: string = AiService.extractJson(raw);
      const obj: AiAnswerRetryRaw = JSON.parse(jsonStr) as AiAnswerRetryRaw;
      const answer: string = obj.myAnswer !== undefined ? obj.myAnswer.trim() : '';
      const present: boolean = obj.myAnswerPresent === true;
      result.myAnswer = answer;
      result.myAnswerPresent = present || answer.length > 0;
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'student answer retry finished: present=%{public}b, answerLength=%{public}d',
        result.myAnswerPresent, answer.length);
    } catch (e) {
      AiService.logError('student answer retry parse/request', e);
    }
    return result;
  }

  private static parseQuestion(raw: string): AiQuestionResult {
    const result: AiQuestionResult = new AiQuestionResult();
    try {
      const jsonStr: string = AiService.extractJson(raw);
      const normalized: string = AiService.normalizeQuestionJson(jsonStr);
      const obj: AiQuestionRaw = JSON.parse(normalized) as AiQuestionRaw;
      result.question = AiService.firstText(obj.question, obj.title);
      result.myAnswer = obj.myAnswer !== undefined ? obj.myAnswer : '';
      result.myAnswerPresent = obj.myAnswerPresent === true || result.myAnswer.length > 0;
      result.standardAnswer = obj.standardAnswer !== undefined ? obj.standardAnswer : '';
      result.knowledgeSummary = AiService.cleanText(
        obj.knowledgeSummary !== undefined ? obj.knowledgeSummary : '');
      const tags: string[] | undefined = obj.knowledgeTags !== undefined
        ? obj.knowledgeTags
        : obj.tags;
      result.subject = obj.subject !== undefined ? AiService.mapSubject(obj.subject) : Subject.MATH;
      result.answerType = obj.answerType !== undefined
        ? AiService.mapAnswerType(obj.answerType) : AnswerType.TEXT;
      result.errorType = obj.errorType !== undefined
        ? AiService.mapErrorType(obj.errorType) : ErrorType.OTHER;
      if (tags !== undefined) {
        result.tags = tags;
      }
      result.ok = result.question.length > 0;
      if (!result.ok) {
        result.error = 'AI 返回内容缺少题目字段';
      }
    } catch (e) {
      result.error = '题目 JSON 解析失败: ' + AiService.errText(e);
    }
    return result;
  }

  private static parseQuestions(raw: string): AiQuestionBatch {
    const batch: AiQuestionBatch = new AiQuestionBatch();
    try {
      const jsonStr: string = AiService.extractJson(raw);
      const parsed: Object = JSON.parse(jsonStr) as Object;
      let rawItems: AiQuestionRaw[] = [];
      if (parsed instanceof Array) {
        rawItems = parsed as AiQuestionRaw[];
      } else {
        const obj: AiQuestionListRaw = parsed as AiQuestionListRaw;
        if (obj.questions !== undefined) {
          rawItems = obj.questions;
        } else if (obj.items !== undefined) {
          rawItems = obj.items;
        } else {
          rawItems = [obj as AiQuestionRaw];
        }
      }
      for (const item of rawItems) {
        const result: AiQuestionResult = AiService.parseQuestion(JSON.stringify(item));
        if (result.ok) {
          batch.items.push(result);
        }
      }
      batch.ok = batch.items.length > 0;
      if (!batch.ok) {
        batch.error = 'AI 返回内容中没有可用题目';
      }
    } catch (e) {
      batch.error = '多题 JSON 解析失败: ' + AiService.errText(e);
    }
    return batch;
  }

  private static parsePlainQuestions(text: string): AiQuestionResult[] {
    const lines: string[] = text.split(/[\r\n]+/);
    const items: AiQuestionResult[] = [];
    let current: string[] = [];
    for (const line of lines) {
      const trimmed: string = line.trim();
      if (trimmed.length === 0) {
        continue;
      }
      if (AiService.isQuestionNumberLine(trimmed) && current.length > 0) {
        AiService.pushPlainQuestion(items, current);
        current = [];
      }
      current.push(trimmed);
    }
    AiService.pushPlainQuestion(items, current);
    return items;
  }

  private static isQuestionNumberLine(line: string): boolean {
    return /^(\d{1,2}[.、．)]|[一二三四五六七八九十]{1,3}[、.．)])/.test(line);
  }

  private static pushPlainQuestion(items: AiQuestionResult[], lines: string[]): void {
    if (lines.length === 0) {
      return;
    }
    const item: AiQuestionResult = new AiQuestionResult();
    item.question = lines.join('\n');
    item.ok = item.question.length > 0;
    items.push(item);
  }

  private static normalizeQuestionJson(json: string): string {
    return json
      .replace(/"题目"/g, '"question"')
      .replace(/"题干"/g, '"question"')
      .replace(/"我的答案"/g, '"myAnswer"')
      .replace(/"学生答案"/g, '"myAnswer"')
      .replace(/"标准答案"/g, '"standardAnswer"')
      .replace(/"正确答案"/g, '"standardAnswer"')
      .replace(/"知识点"/g, '"knowledgeSummary"')
      .replace(/"知识点标签"/g, '"knowledgeTags"')
      .replace(/"标签"/g, '"knowledgeTags"');
  }

  private static firstText(value1: string | undefined, value2?: string | undefined,
    value3?: string | undefined): string {
    if (value1 !== undefined && value1.length > 0) {
      return value1;
    }
    if (value2 !== undefined && value2.length > 0) {
      return value2;
    }
    if (value3 !== undefined && value3.length > 0) {
      return value3;
    }
    return '';
  }

  private static plainQuestionText(raw: string): string {
    let text: string = raw.trim();
    if (text.startsWith('```')) {
      const firstNewline: number = text.indexOf('\n');
      if (firstNewline >= 0) {
        text = text.substring(firstNewline + 1);
      }
      const fenceEnd: number = text.lastIndexOf('```');
      if (fenceEnd >= 0) {
        text = text.substring(0, fenceEnd);
      }
    }
    text = text.replace(/^(识别结果|识别内容|题目内容|题目)\s*[:：]\s*/, '').trim();
    return text;
  }

  private static mapErrorType(s: string): ErrorType {
    if (s === 'concept') {
      return ErrorType.CONCEPT;
    }
    if (s === 'careless') {
      return ErrorType.CARELESS;
    }
    if (s === 'misread') {
      return ErrorType.MISREAD;
    }
    return ErrorType.OTHER;
  }

  static async analyzeMistake(question: string, myAnswer: string, standardAnswer: string): Promise<AiAnalysis> {
    const prompt: string =
      '请分析以下错题并以纯JSON返回（不要markdown代码块、不要解释）。\n' +
      '题目：' + question + '\n我的答案：' + myAnswer + '\n标准答案：' + standardAnswer + '\n' +
      '返回格式：{"analysis":"简短的错误点分析","answerType":"choice或numeric或text或subjective","subject":"math或chinese或english或science","knowledgeTags":["标签1","标签2"]}\n' +
      'answerType 只能是 choice/numeric/text/subjective 之一；subject 只能是 math/chinese/english/science 之一。只输出JSON。';
    const part: AiContentPart = { type: 'text', text: prompt };
    const raw: string = await AiService.request([{ role: 'user', content: [part] }]);
    const result: AiAnalysis = AiService.parseAnalysis(raw);
    if (result.error.length > 0) {
      hilog.error(LOG_DOMAIN, LOG_TAG,
        'analyzeMistake parse failed: error=%{public}s, raw=%{public}s',
        result.error, AiService.logBody(raw));
    }
    return result;
  }

  /**
   * 方案 A：GLM 负责生成教学脚本与分镜，App 内播放动画式讲解视频。
   */
  static async generateLesson(question: string, studentAnswer: string, standardAnswer: string,
    grade: string, subject: string, knowledgeSummary: string, errorType: string): Promise<AiLesson> {
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'generateLesson start: questionLength=%{public}d, studentAnswerLength=%{public}d, ' +
        'standardAnswerLength=%{public}d, grade=%{public}s, subject=%{public}s, ' +
        'knowledgeSummaryLength=%{public}d, errorType=%{public}s, model=%{public}s',
      question.length, studentAnswer.length, standardAnswer.length, grade, subject,
      knowledgeSummary.length, errorType, AiConfig.model);
    const prompt: string =
      '请为一个小学生错题生成App内动画讲解视频脚本。脚本必须根据学生年级调整语言难度，语气亲切、鼓励，不批评孩子。\n' +
      `学生年级：${grade}年级\n学科：${subject}\n知识点：${knowledgeSummary}\n错误类型：${errorType}\n` +
      `题目：${question}\n学生答案：${studentAnswer.length > 0 ? studentAnswer : '未提供'}\n标准答案：${standardAnswer.length > 0 ? standardAnswer : '未提供'}\n\n` +
      '生成要求：\n' +
      '1. 4-6个scenes，总时长35-55秒，优先精炼，不追求长视频。\n' +
      '2. 结构包含：亲切开场、读题、理解学生答案、定位错误原因、正确解法分步讲解、检查答案、鼓励总结。\n' +
      '3. narration每句不超过38个中文字，适合朗读；subtitle不超过12个中文字。\n' +
      '4. 数学步骤要拆小，每步只讲一个动作；语文/英语/科学用适合年级的方式解释。\n' +
      '5. screen.type只能是cover/question/compare/steps/tip之一。\n' +
      '6. steps场景的screen.steps放2-3条短步骤，每条不超过18个字。\n' +
      '7. 每个screen必须带visual字段，用图形表达思考过程，不能只给文字。visual.type只能是fraction_bars/number_line/counters/arrow_flow/shape_combo/icon_story之一。\n' +
      '8. visual字段要求：fraction_bars用于分数、倍数、比例，输出labels/numerators/denominators/resultNumerator/resultDenominator；number_line输出labels/nodes/highlightIndex；counters输出icons/captions；arrow_flow输出nodes，每步一个节点；shape_combo输出labels/nodes/icons；icon_story输出icons/captions。小学题目优先选能讲清因果的图形，不要每次都用arrow_flow。\n' +
      '9. 不得编造题目没有的信息；标准答案未提供时要提醒家长核对。\n' +
      '10. 只输出纯JSON，不要markdown代码块和解释。\n' +
      'screen只输出该type需要的字段：cover输出title/text；question输出title/text/highlight；compare输出title/studentAnswer/standardAnswer；steps输出title/steps；tip输出title/text。不要输出空字段。\n' +
      '返回格式：{"title":"不超过10字","totalDuration":45,"gradeLevel":"三年级","tone":"亲切鼓励","scenes":[{"id":"intro","duration":5,"narration":"...","subtitle":"...","screen":{"type":"steps","title":"...","steps":["..."],"visual":{"type":"fraction_bars","labels":["3/8","1/4","5/8"],"numerators":[3,1,5],"denominators":[8,4,8],"resultNumerator":5,"resultDenominator":8,"nodes":[],"icons":[],"captions":[],"highlightIndex":2}},"animation":"bar_grow"}]}\n' +
      'JSON字段名必须使用英文。';
    const part: AiContentPart = { type: 'text', text: prompt };
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'generateLesson request ready: promptLength=%{public}d, inputQuestionEmpty=%{public}b',
      prompt.length, question.trim().length === 0);
    const raw: string = await AiService.request(
      [{ role: 'user', content: [part] }], 4096, REASONING_EFFORT_LOW);
    AiService.logLongInfo('generateLesson raw content',
      `rawLength=${raw.length}\npreview=${AiService.logBody(raw)}`);
    const lesson: AiLesson = AiService.parseLesson(raw);
    if (lesson.scenes.length === 0) {
      const parseError: string = lesson.error.length > 0 ? lesson.error : '未解析到可用 scenes';
      AiService.logLongError('generateLesson parse failed',
        `error=${parseError}\nrawLength=${raw.length}\nraw=${AiService.logBody(raw)}`);
      throw new AiServiceError('讲解视频脚本生成失败，请重试',
        '讲解视频脚本解析失败\n' +
        `model=${AiConfig.model}\n` +
        `error=${parseError}\n` +
        `rawLength=${raw.length}\n` +
        `raw=${AiService.logBody(raw)}`);
    }
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'generateLesson success: sceneCount=%{public}d, totalDuration=%{public}d, title=%{public}s',
      lesson.scenes.length, lesson.totalDuration, lesson.title);
    return lesson;
  }

  private static parseLesson(raw: string): AiLesson {
    const lesson: AiLesson = new AiLesson();
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'parseLesson start: rawLength=%{public}d', raw.length);
    try {
      const jsonStr: string = AiService.extractJson(raw);
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'parseLesson json extracted: jsonLength=%{public}d, objectStart=%{public}d, objectEnd=%{public}d',
        jsonStr.length, raw.indexOf('{'), raw.lastIndexOf('}'));
      const obj: AiLessonRaw = JSON.parse(jsonStr) as AiLessonRaw;
      lesson.title = obj.title !== undefined && obj.title.length > 0 ? obj.title : '错题讲解';
      lesson.gradeLevel = obj.gradeLevel !== undefined ? obj.gradeLevel : '';
      lesson.tone = obj.tone !== undefined && obj.tone.length > 0 ? obj.tone : lesson.tone;
      if (obj.scenes !== undefined) {
        for (const rawScene of obj.scenes) {
          const scene: AiLessonScene = new AiLessonScene();
          scene.id = rawScene.id !== undefined && rawScene.id.length > 0 ? rawScene.id : `scene_${lesson.scenes.length + 1}`;
          scene.narration = rawScene.narration !== undefined ? rawScene.narration : '';
          scene.subtitle = rawScene.subtitle !== undefined && rawScene.subtitle.length > 0
            ? rawScene.subtitle : scene.narration;
          scene.duration = AiService.sceneDuration(rawScene.duration, scene.narration);
          scene.animation = rawScene.animation !== undefined ? rawScene.animation : '';
          if (rawScene.screen !== undefined) {
            const rawScreen: AiLessonScreenRaw = rawScene.screen;
            scene.screen.type = AiService.normalizeLessonScreenType(rawScreen.type);
            scene.screen.title = rawScreen.title !== undefined ? rawScreen.title : '';
            scene.screen.text = rawScreen.text !== undefined ? rawScreen.text : '';
            scene.screen.highlight = rawScreen.highlight !== undefined ? rawScreen.highlight : '';
            scene.screen.studentAnswer = rawScreen.studentAnswer !== undefined ? rawScreen.studentAnswer : '';
            scene.screen.standardAnswer = rawScreen.standardAnswer !== undefined ? rawScreen.standardAnswer : '';
          if (rawScreen.steps !== undefined) {
            scene.screen.steps = rawScreen.steps;
          }
          if (rawScreen.visual !== undefined) {
            scene.screen.visual = AiService.parseLessonVisual(rawScreen.visual);
          }
          if (rawScreen.type !== undefined && AiService.normalizeLessonScreenType(rawScreen.type) === 'text') {
            hilog.warn(LOG_DOMAIN, LOG_TAG,
              'parseLesson unknown screen type: sceneId=%{public}s, type=%{public}s',
              scene.id, rawScreen.type);
          }
        } else {
          hilog.warn(LOG_DOMAIN, LOG_TAG,
            'parseLesson scene missing screen: sceneId=%{public}s, subtitle=%{public}s',
            scene.id, scene.subtitle);
        }
        if (scene.narration.length > 0) {
          lesson.scenes.push(scene);
        } else {
          hilog.warn(LOG_DOMAIN, LOG_TAG,
            'parseLesson scene missing narration and skipped: sceneId=%{public}s, rawScene=%{public}s',
            scene.id, JSON.stringify(rawScene));
        }
      }
    } else {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'parseLesson response has no scenes array');
    }
      lesson.totalDuration = AiService.lessonDuration(lesson, obj.totalDuration);
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'parseLesson success: parsedSceneCount=%{public}d, totalDuration=%{public}d',
        lesson.scenes.length, lesson.totalDuration);
    } catch (e) {
      lesson.error = AiService.errText(e);
      AiService.logError('parse lesson', e);
    }
    return lesson;
  }

  private static clampDuration(value: number | undefined): number {
    if (value === undefined || value < 3) {
      return 5;
    }
    if (value > 16) {
      return 16;
    }
    return Math.round(value);
  }

  private static sceneDuration(modelValue: number | undefined, narration: string): number {
    const modelDuration: number = AiService.clampDuration(modelValue);
    const speechDuration: number = Math.ceil(narration.length / 3.6) + 1;
    return Math.max(modelDuration, Math.min(20, speechDuration));
  }

  private static lessonDuration(lesson: AiLesson, modelValue: number | undefined): number {
    let total: number = 0;
    for (const scene of lesson.scenes) {
      total += scene.duration;
    }
    if (modelValue !== undefined && modelValue > 0 && Math.abs(modelValue - total) <= 10) {
      return Math.round(modelValue);
    }
    return total;
  }

  private static normalizeLessonScreenType(value: string | undefined): string {
    if (value === 'cover' || value === 'question' || value === 'compare' || value === 'steps' || value === 'tip') {
      return value;
    }
    return 'text';
  }

  private static parseLessonVisual(raw: AiLessonVisualRaw): AiLessonVisual {
    const visual: AiLessonVisual = new AiLessonVisual();
    visual.type = raw.type !== undefined ? raw.type : '';
    if (raw.labels !== undefined) {
      visual.labels = raw.labels;
    }
    if (raw.numerators !== undefined) {
      visual.numerators = raw.numerators;
    }
    if (raw.denominators !== undefined) {
      visual.denominators = raw.denominators;
    }
    visual.resultNumerator = raw.resultNumerator !== undefined ? raw.resultNumerator : 0;
    visual.resultDenominator = raw.resultDenominator !== undefined ? raw.resultDenominator : 0;
    if (raw.nodes !== undefined) {
      visual.nodes = raw.nodes;
    }
    if (raw.icons !== undefined) {
      visual.icons = raw.icons;
    }
    if (raw.captions !== undefined) {
      visual.captions = raw.captions;
    }
    visual.highlightIndex = raw.highlightIndex !== undefined ? raw.highlightIndex : 0;
    return visual;
  }

  private static async request(messages: AiMessage[], maxTokens: number = 8192,
    reasoningEffort: string = REASONING_EFFORT_LOW): Promise<string> {
    const httpRequest: http.HttpRequest = http.createHttp();
    const requestStart: number = Date.now();
    try {
      await AiService.ensureConfig();
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'AI request start: model=%{public}s, url=%{public}s, messages=%{public}d, apiKeyLength=%{public}d, thinkingType=%{public}s, reasoningEffort=%{public}s',
        AiConfig.model, AiConfig.baseUrl, messages.length, AiConfig.apiKey.length,
        THINKING_ENABLED, reasoningEffort);
      const bodyObj: Record<string, Object> = {
        'model': AiConfig.model,
        'messages': messages as Object,
        'temperature': 0.1 as Object,
      };
      bodyObj['max_tokens'] = maxTokens as Object;
      const thinking: AiThinking = { type: THINKING_ENABLED, clear_thinking: false };
      bodyObj['thinking'] = thinking as Object;
      bodyObj['reasoning_effort'] = reasoningEffort as Object;
      const response = await httpRequest.request(AiConfig.baseUrl, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + AiConfig.apiKey },
        extraData: JSON.stringify(bodyObj),
        connectTimeout: 30000,
        readTimeout: 90000
      });
      const bodyStr: string = AiService.responseBodyText(response.result);
      const elapsedMs: number = Date.now() - requestStart;
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'AI response received: httpCode=%{public}d, bodyLength=%{public}d, elapsedMs=%{public}d',
        response.responseCode, bodyStr.length, elapsedMs);
      if (response.responseCode !== 200) {
        const diagnostic: string = AiService.responseDiagnostic(bodyStr, response.responseCode, undefined);
        AiService.logLongError('AI HTTP error', diagnostic);
        throw new AiServiceError(AiService.friendlyHttpMessage('AI处理', response.responseCode, bodyStr),
          diagnostic);
      }
      let respObj: AiResponse;
      try {
        respObj = JSON.parse(bodyStr) as AiResponse;
      } catch (e) {
        AiService.logLongError('AI response non-JSON',
          AiService.responseDiagnostic(bodyStr, response.responseCode, undefined));
        throw new AiServiceError('AI返回非JSON: ' + AiService.summary(bodyStr),
          AiService.responseDiagnostic(bodyStr, response.responseCode, undefined));
      }
      if (respObj.choices === undefined || respObj.choices.length === 0) {
        AiService.logLongError('AI response choices empty',
          AiService.responseDiagnostic(bodyStr, response.responseCode, respObj.usage));
        throw new AiServiceError('AI返回为空: ' + AiService.summary(bodyStr),
          AiService.responseDiagnostic(bodyStr, response.responseCode, respObj.usage));
      }
      const rawContent: string | undefined = respObj.choices[0].message.content;
      const reasoningContent: string | undefined = respObj.choices[0].message.reasoning_content;
      const content: string = rawContent === undefined ? '' : rawContent;
      const finishReasonLog: string = respObj.choices[0].finish_reason !== undefined
        ? respObj.choices[0].finish_reason : 'unknown';
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'AI choice parsed: choices=%{public}d, finishReason=%{public}s, contentLength=%{public}d, ' +
          'reasoningContentLength=%{public}d, promptTokens=%{public}s, completionTokens=%{public}s, totalTokens=%{public}s',
        respObj.choices.length,
        finishReasonLog,
        content.length,
        reasoningContent === undefined ? -1 : reasoningContent.length,
        respObj.usage !== undefined && respObj.usage.prompt_tokens !== undefined
          ? `${respObj.usage.prompt_tokens}` : 'unknown',
        respObj.usage !== undefined && respObj.usage.completion_tokens !== undefined
          ? `${respObj.usage.completion_tokens}` : 'unknown',
        respObj.usage !== undefined && respObj.usage.total_tokens !== undefined
          ? `${respObj.usage.total_tokens}` : 'unknown');
      if (content.trim().length === 0) {
        const finishReason: string = respObj.choices[0].finish_reason !== undefined
          ? respObj.choices[0].finish_reason : 'unknown';
        const emptyDiagnostic: string =
          `AI message content empty\nfinishReason=${finishReason}\n` +
          `contentLength=${content.length}\n` +
          `reasoningContentLength=${reasoningContent === undefined ? -1 : reasoningContent.length}\n` +
          AiService.responseDiagnostic(bodyStr, response.responseCode, respObj.usage);
        AiService.logLongError('AI content empty', emptyDiagnostic);
        throw new AiServiceError(`AI返回内容为空（finish_reason=${finishReason}）`,
          emptyDiagnostic);
      }
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'AI content return: contentLength=%{public}d, elapsedMs=%{public}d',
        content.length, Date.now() - requestStart);
      return content;
    } catch (e) {
      AiService.logError('AI request', e);
      if (e instanceof AiServiceError) {
        throw e;
      }
      const elapsedMs: number = Date.now() - requestStart;
      const diagnostic: string = 'AI请求异常完整诊断\n' +
        `model=${AiConfig.model}\n` +
        `url=${AiConfig.baseUrl}\n` +
        `elapsedMs=${elapsedMs}\n` +
        `connectTimeoutMs=30000\n` +
        `readTimeoutMs=180000\n` +
        `error=${AiService.errorDetail(e)}`;
      const requestError: AiServiceError =
        new AiServiceError(AiService.userMessage(e, 'AI请求异常，请检查网络后重试'), diagnostic);
      AiService.logLongError('AI request exception diagnostic', diagnostic);
      throw requestError;
    } finally {
      httpRequest.destroy();
    }
  }

  private static responseBodyText(result: string | Object | ArrayBuffer): string {
    try {
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'AI response body decode: resultType=%{public}s, isArrayBuffer=%{public}b',
        typeof result, result instanceof ArrayBuffer);
      if (typeof result === 'string') {
        return result as string;
      }
      if (result instanceof ArrayBuffer) {
        const textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8');
        return textDecoder.decodeToString(new Uint8Array(result as ArrayBuffer));
      }
      return `${result}`;
    } catch (e) {
      AiService.logLongError('AI response body decode failed', AiService.errorDetail(e));
      return '';
    }
  }

  private static normalizeVoiceSubject(value: string | undefined): string {
    const subject: string = value !== undefined ? value.trim() : '';
    if (subject === 'math' || subject === 'chinese' || subject === 'english' || subject === 'science' ||
      subject === 'history' || subject === 'geography' || subject === 'technology' || subject === 'life' ||
      subject === 'art' || subject === 'sports') {
      return subject;
    }
    return 'other';
  }

  private static normalizeVoiceQuestionType(value: string | undefined): string {
    const type: string = value !== undefined ? value.trim() : '';
    if (type === 'reason' || type === 'compare' || type === 'imagine' || type === 'how_to' || type === 'help') {
      return type;
    }
    return 'fact';
  }

  /** 给页面使用的异常文案：技术细节保留在 diagnostic/hilog，用户只看可执行提示。 */
  static userMessage(e: Object, fallback: string): string {
    if (e instanceof AiServiceError) {
      if (AiService.isTechnicalMessage(e.message)) {
        return AiService.friendlyServerMessage(e.diagnostic, fallback);
      }
      return e.message;
    }

    if (e instanceof Error && AiService.hasChinese(e.message) &&
      e.message.indexOf('[object Object]') < 0 && e.message.indexOf('object Object') < 0) {
      return e.message;
    }

    const detail: string = AiService.errorDetail(e).toLowerCase();
    if (detail.indexOf('2300028') >= 0 || detail.indexOf('timeout') >= 0 ||
      detail.indexOf('timed out') >= 0) {
      return 'AI 处理超时，请稍后重试；如果连续出现，请缩短问题后再试';
    }
    if (detail.indexOf('201') >= 0 || detail.indexOf('permission') >= 0) {
      return '缺少系统权限，请在系统设置中检查授权后重试';
    }
    if (detail.indexOf('network') >= 0 || detail.indexOf('connect') >= 0 ||
      detail.indexOf('connection') >= 0) {
      return '网络连接失败，请检查网络后重试';
    }
    if (detail.indexOf('1113') >= 0) {
      return 'AI 服务余额不足或没有可用资源包，请到智谱开放平台充值或开通资源包';
    }
    if (detail.indexOf('1000') >= 0 || detail.indexOf('401') >= 0 ||
      detail.indexOf('unauthorized') >= 0 || detail.indexOf('身份验证失败') >= 0) {
      return 'AI 身份验证失败，请检查 API Key 是否正确、过期或无权限';
    }
    return fallback;
  }

  private static isTechnicalMessage(message: string): boolean {
    return message.indexOf('[object Object]') >= 0 || message.indexOf('object Object') >= 0 ||
      message.indexOf('HTTP ') >= 0 || message.indexOf('name=') >= 0 ||
      message.indexOf('code=') >= 0 || message.indexOf('{"error"') >= 0;
  }

  private static friendlyHttpMessage(action: string, httpCode: number, body: string): string {
    if (httpCode === 401 || httpCode === 403) {
      return 'AI 身份验证失败，请检查 API Key 是否正确、过期或无权限';
    }
    if (httpCode === 404) {
      return 'AI 服务接口不可用，请更新应用或稍后再试';
    }
    if (httpCode === 502 || httpCode === 503 || httpCode === 504) {
      return 'AI 服务暂时不可用或处理超时，请稍后重试';
    }
    return AiService.friendlyServerMessage(body, `${action}失败，请稍后重试`);
  }

  private static friendlyServerMessage(body: string, fallback: string): string {
    const code: string = AiService.extractJsonStringField(body, 'code');
    const message: string = AiService.extractJsonStringField(body, 'message');
    const combined: string = `${code} ${message}`;

    if (combined.indexOf('1113') >= 0 || combined.indexOf('余额不足') >= 0 ||
      combined.indexOf('资源包') >= 0) {
      return 'AI 服务余额不足或没有可用资源包，请到智谱开放平台充值或开通资源包';
    }
    if (combined.indexOf('1000') >= 0 || combined.indexOf('401') >= 0 ||
      combined.indexOf('身份验证失败') >= 0 || combined.indexOf('unauthorized') >= 0) {
      return 'AI 身份验证失败，请检查 API Key 是否正确、过期或无权限';
    }
    if (combined.indexOf('2300028') >= 0 || combined.indexOf('timeout') >= 0 ||
      combined.indexOf('operation timeout') >= 0) {
      return 'AI 处理超时，请稍后重试；如果连续出现，请缩短问题后再试';
    }
    if (combined.indexOf('1210') >= 0 || combined.indexOf('thinking') >= 0) {
      return '当前模型参数不兼容，请更新应用后再试';
    }
    if (combined.indexOf('1214') >= 0) {
      return '语音文件没有被服务端接收，请重新录制后再试';
    }

    if (AiService.hasChinese(message) && message.indexOf('[object Object]') < 0) {
      return `${fallback}：${message}`;
    }
    if (code.length > 0) {
      return `${fallback}（错误码 ${code}）`;
    }
    return fallback;
  }

  private static extractJsonStringField(body: string, field: string): string {
    const marker: string = `"${field}"`;
    const fieldStart: number = body.indexOf(marker);
    if (fieldStart < 0) {
      return '';
    }
    const colon: number = body.indexOf(':', fieldStart + marker.length);
    if (colon < 0) {
      return '';
    }
    let start: number = colon + 1;
    while (start < body.length && (body.charAt(start) === ' ' || body.charAt(start) === '\n' ||
      body.charAt(start) === '\r' || body.charAt(start) === '\t')) {
      start++;
    }
    if (body.charAt(start) >= '0' && body.charAt(start) <= '9') {
      let numberEnd: number = start;
      while (numberEnd < body.length && body.charAt(numberEnd) >= '0' &&
        body.charAt(numberEnd) <= '9') {
        numberEnd++;
      }
      return body.substring(start, numberEnd);
    }
    if (start >= body.length || body.charAt(start) !== '"') {
      return '';
    }
    let end: number = start + 1;
    while (end < body.length) {
      if (body.charAt(end) === '\\') {
        end += 2;
        continue;
      }
      if (body.charAt(end) === '"') {
        return body.substring(start + 1, end);
      }
      end++;
    }
    return '';
  }

  private static hasChinese(text: string): boolean {
    for (let i: number = 0; i < text.length; i++) {
      const code: number = text.charCodeAt(i);
      if (code >= 0x4E00 && code <= 0x9FFF) {
        return true;
      }
    }
    return false;
  }

  private static responseDiagnostic(body: string, httpCode: number, usage: AiResponseUsage | undefined,
    model: string = AiConfig.model, url: string = AiConfig.baseUrl): string {
    const promptTokens: string = usage !== undefined && usage.prompt_tokens !== undefined
      ? `${usage.prompt_tokens}` : 'unknown';
    const completionTokens: string = usage !== undefined && usage.completion_tokens !== undefined
      ? `${usage.completion_tokens}` : 'unknown';
    const totalTokens: string = usage !== undefined && usage.total_tokens !== undefined
      ? `${usage.total_tokens}` : 'unknown';
    return 'AI服务完整诊断\n' +
      `model=${model}\n` +
      `url=${url}\n` +
      `httpCode=${httpCode}\n` +
      `bodyLength=${body.length}\n` +
      `usage.promptTokens=${promptTokens}\n` +
      `usage.completionTokens=${completionTokens}\n` +
      `usage.totalTokens=${totalTokens}\n` +
      `response=${AiService.logBody(body)}`;
  }

  private static summary(body: string): string {
    if (body.length <= BODY_SUMMARY_MAX) {
      return body;
    }
    return body.substring(0, BODY_SUMMARY_MAX) + '...';
  }

  private static logBody(body: string): string {
    if (body.length <= LOG_BODY_MAX) {
      return body;
    }
    return body.substring(0, LOG_BODY_MAX) + `... (${body.length} chars)`;
  }

  private static logError(stage: string, e: Object): void {
    hilog.error(LOG_DOMAIN, LOG_TAG, '%{public}s failed: %{public}s',
      stage, AiService.errorDetail(e));
    if (e instanceof AiServiceError && e.diagnostic.length > 0) {
      AiService.logLongError(stage + ' diagnostic', e.diagnostic);
    }
  }

  /**
   * HiLog 单条输出可能被系统截断；错误诊断按固定长度分段输出，
   * 确保 HTTP 超时、响应体、finish_reason、usage 等关键信息都能进入日志。
   */
  private static logLongError(stage: string, content: string): void {
    const text: string = content.length > 0 ? content : '(empty diagnostic)';
    const totalChunks: number = Math.ceil(text.length / LOG_CHUNK_MAX);
    for (let i: number = 0; i < totalChunks; i++) {
      const start: number = i * LOG_CHUNK_MAX;
      const end: number = Math.min(start + LOG_CHUNK_MAX, text.length);
      hilog.error(LOG_DOMAIN, LOG_TAG,
        '%{public}s [%{public}d/%{public}d]: %{public}s',
        stage, i + 1, totalChunks, text.substring(start, end));
    }
  }

  private static logLongInfo(stage: string, content: string): void {
    const text: string = content.length > 0 ? content : '(empty content)';
    const totalChunks: number = Math.ceil(text.length / LOG_CHUNK_MAX);
    for (let i: number = 0; i < totalChunks; i++) {
      const start: number = i * LOG_CHUNK_MAX;
      const end: number = Math.min(start + LOG_CHUNK_MAX, text.length);
      hilog.info(LOG_DOMAIN, LOG_TAG,
        '%{public}s [%{public}d/%{public}d]: %{public}s',
        stage, i + 1, totalChunks, text.substring(start, end));
    }
  }

  private static errorDetail(e: Object): string {
    const businessError: BusinessError = e as BusinessError;
    const parts: string[] = [];
    if (businessError.code !== undefined) {
      parts.push(`code=${businessError.code}`);
    }
    if (businessError.name !== undefined && businessError.name.length > 0) {
      parts.push(`name=${businessError.name}`);
    }
    if (businessError.message !== undefined && businessError.message.length > 0) {
      parts.push(`message=${businessError.message}`);
    }
    if (e instanceof Error && e.stack !== undefined && e.stack.length > 0) {
      parts.push(`stack=${e.stack}`);
    }
    if (parts.length === 0) {
      parts.push(`${e}`);
    }
    return parts.join(', ');
  }

  private static cleanText(raw: string): string {
    let s: string = raw.replace(/[\\n\\r\\t"'`]/g, '').trim();
    if (s.length > 10) {
      s = s.substring(0, 10);
    }
    return s;
  }

  private static parseAnalysis(raw: string): AiAnalysis {
    const result: AiAnalysis = new AiAnalysis();
    try {
      const jsonStr: string = AiService.extractJson(raw);
      const obj: AiAnalysisRaw = JSON.parse(jsonStr) as AiAnalysisRaw;
      result.analysis = obj.analysis !== undefined ? obj.analysis : '';
      result.answerType = AiService.mapAnswerType(obj.answerType);
      result.subject = AiService.mapSubject(obj.subject);
      if (obj.knowledgeTags !== undefined) {
        result.tags = obj.knowledgeTags;
      }
      if (result.analysis.length === 0) {
        result.error = 'AI 返回内容缺少分析字段';
      }
    } catch (e) {
      result.error = '分析 JSON 解析失败: ' + AiService.errText(e);
    }
    return result;
  }

  private static extractJson(raw: string): string {
    const objectStart: number = raw.indexOf('{');
    const arrayStart: number = raw.indexOf('[');
    let start: number = -1;
    let endChar: string = '';
    if (arrayStart >= 0 && (objectStart < 0 || arrayStart < objectStart)) {
      start = arrayStart;
      endChar = ']';
    } else {
      start = objectStart;
      endChar = '}';
    }
    const end: number = raw.lastIndexOf(endChar);
    if (start >= 0 && end > start) {
      return raw.substring(start, end + 1);
    }
    return raw;
  }

  private static mapAnswerType(s: string): AnswerType {
    if (s === 'choice') {
      return AnswerType.CHOICE;
    }
    if (s === 'numeric') {
      return AnswerType.NUMERIC;
    }
    if (s === 'subjective') {
      return AnswerType.SUBJECTIVE;
    }
    return AnswerType.TEXT;
  }

  private static mapSubject(s: string): Subject {
    if (s === 'chinese') {
      return Subject.CHINESE;
    }
    if (s === 'english') {
      return Subject.ENGLISH;
    }
    if (s === 'science') {
      return Subject.SCIENCE;
    }
    return Subject.MATH;
  }

  private static errText(e: Object): string {
    if (e instanceof Error) {
      return e.message;
    }
    return `${e}`;
  }
}
