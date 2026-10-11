import http from '@ohos.net.http';
import util from '@ohos.util';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Subject, AnswerType, ErrorType } from '../models/Enums';
import { MediaService } from './MediaService';
import { AiConfig } from '../common/AiConfig';

const CONFIG_GUIDE: string =
  'AI 未配置：请在 entry/src/main/resources/rawfile/apiconfig.json 中配置 apiKey';
const BODY_SUMMARY_MAX: number = 160;
const LOG_BODY_MAX: number = 2000;
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
  content: string;
}

interface AiResponseChoice {
  message: AiResponseMessage;
}

interface AiResponse {
  choices: AiResponseChoice[];
}

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

export class AiAnalysis {
  analysis: string = '';
  answerType: AnswerType = AnswerType.TEXT;
  subject: Subject = Subject.MATH;
  tags: string[] = [];
  error: string = '';
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

export class AiLessonScreen {
  type: string = 'text';
  title: string = '';
  text: string = '';
  highlight: string = '';
  steps: string[] = [];
  studentAnswer: string = '';
  standardAnswer: string = '';
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
}

export class AiService {
  private static async ensureConfig(): Promise<void> {
    await AiConfig.load();
    if (!AiConfig.configured) {
      throw new Error(CONFIG_GUIDE);
    }
  }

  static async recognizeImage(imagePath: string): Promise<string> {
    let base64: string | undefined;
    try {
      base64 = await MediaService.readImageBase64(imagePath, 1280);
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
      text: '请识别图片中的文字内容，原样输出，不要添加任何解释、标点或提示语。'
    };
    const msg: AiMessage = { role: 'user', content: [part1, part2] };
    return AiService.request([msg]);
  }

  /**
   * AI 全图识别（无本地 OCR 环节）：直接把整张错题照片交给多模态模型，
   * 一次性提取题目、我的答案、标准答案、学科、题型、错误类型与知识点。
   */
  static async recognizeQuestion(imagePath: string): Promise<AiQuestionResult> {
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
    const prompt: string =
      '请为一个小学生错题生成App内动画讲解视频脚本。脚本必须根据学生年级调整语言难度，语气亲切、鼓励，不批评孩子。\n' +
      `学生年级：${grade}年级\n学科：${subject}\n知识点：${knowledgeSummary}\n错误类型：${errorType}\n` +
      `题目：${question}\n学生答案：${studentAnswer.length > 0 ? studentAnswer : '未提供'}\n标准答案：${standardAnswer.length > 0 ? standardAnswer : '未提供'}\n\n` +
      '生成要求：\n' +
      '1. 6-8个scenes，总时长50-80秒。\n' +
      '2. 结构包含：亲切开场、读题、理解学生答案、定位错误原因、正确解法分步讲解、检查答案、鼓励总结。\n' +
      '3. narration每句不超过55个中文字，适合朗读；subtitle不超过18个中文字。\n' +
      '4. 数学步骤要拆小，每步只讲一个动作；语文/英语/科学用适合年级的方式解释。\n' +
      '5. screen.type只能是cover/question/compare/steps/tip之一。\n' +
      '6. steps场景的screen.steps放2-4条短步骤，每条不超过24个字。\n' +
      '7. 不得编造题目没有的信息；标准答案未提供时要提醒家长核对。\n' +
      '8. 只输出纯JSON，不要markdown代码块和解释。\n' +
      '返回格式：{"title":"不超过12字","totalDuration":70,"gradeLevel":"三年级","tone":"亲切鼓励","scenes":[{"id":"intro","duration":6,"narration":"...","subtitle":"...","screen":{"type":"cover","title":"...","text":"...","highlight":"...","steps":["..."],"studentAnswer":"...","standardAnswer":"..."},"animation":"mascot_wave"}]}\n' +
      'JSON字段名必须使用英文。';
    const part: AiContentPart = { type: 'text', text: prompt };
    const raw: string = await AiService.request([{ role: 'user', content: [part] }]);
    const lesson: AiLesson = AiService.parseLesson(raw);
    if (lesson.scenes.length === 0) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'generateLesson parse failed: raw=%{public}s', AiService.logBody(raw));
      throw new Error('讲解视频脚本生成失败，请重试');
    }
    return lesson;
  }

  private static parseLesson(raw: string): AiLesson {
    const lesson: AiLesson = new AiLesson();
    try {
      const jsonStr: string = AiService.extractJson(raw);
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
          }
          if (scene.narration.length > 0) {
            lesson.scenes.push(scene);
          }
        }
      }
      lesson.totalDuration = AiService.lessonDuration(lesson, obj.totalDuration);
    } catch (e) {
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

  private static async request(messages: AiMessage[]): Promise<string> {
    const httpRequest: http.HttpRequest = http.createHttp();
    try {
      await AiService.ensureConfig();
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'AI request start: model=%{public}s, url=%{public}s, messages=%{public}d, apiKeyLength=%{public}d',
        AiConfig.model, AiConfig.baseUrl, messages.length, AiConfig.apiKey.length);
      const bodyObj: Record<string, Object> = {
        'model': AiConfig.model,
        'messages': messages as Object,
        'temperature': 0.1 as Object,
        'max_tokens': 3072 as Object
      };
      const response = await httpRequest.request(AiConfig.baseUrl, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + AiConfig.apiKey },
        extraData: JSON.stringify(bodyObj),
        connectTimeout: 15000,
        readTimeout: 60000
      });
      const bodyStr: string = AiService.responseBodyText(response.result);
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'AI response received: httpCode=%{public}d, bodyLength=%{public}d',
        response.responseCode, bodyStr.length);
      if (response.responseCode !== 200) {
        hilog.error(LOG_DOMAIN, LOG_TAG,
          'AI HTTP error body: httpCode=%{public}d, body=%{public}s',
          response.responseCode, AiService.logBody(bodyStr));
        AiService.logError('AI HTTP request failed with HTTP ' + response.responseCode,
          new Error(AiService.logBody(bodyStr)));
        throw new Error(`AI请求失败: HTTP ${response.responseCode} ${AiService.summary(bodyStr)}`);
      }
      let respObj: AiResponse;
      try {
        respObj = JSON.parse(bodyStr) as AiResponse;
      } catch (e) {
        throw new Error('AI返回非JSON: ' + AiService.summary(bodyStr));
      }
      if (respObj.choices === undefined || respObj.choices.length === 0) {
        throw new Error('AI返回为空: ' + AiService.summary(bodyStr));
      }
      const content: string = respObj.choices[0].message.content;
      if (content === undefined || content.length === 0) {
        throw new Error('AI返回内容为空: ' + AiService.summary(bodyStr));
      }
      return content;
    } catch (e) {
      AiService.logError('AI request', e);
      if (e instanceof Error) {
        throw e;
      }
      throw new Error('AI请求异常: ' + AiService.errorDetail(e));
    } finally {
      httpRequest.destroy();
    }
  }

  private static responseBodyText(result: string | Object | ArrayBuffer): string {
    try {
      if (typeof result === 'string') {
        return result as string;
      }
      if (result instanceof ArrayBuffer) {
        const textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8');
        return textDecoder.decodeToString(new Uint8Array(result as ArrayBuffer));
      }
      return `${result}`;
    } catch (e) {
      return '';
    }
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
    const start: number = raw.indexOf('{');
    const end: number = raw.lastIndexOf('}');
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
