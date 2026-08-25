import http from '@ohos.net.http';
import util from '@ohos.util';
import { Subject, AnswerType, ErrorType } from '../models/Enums';
import { CropFracs } from '../models/Mistake';
import { MediaService } from './MediaService';
import { AiConfig } from '../common/AiConfig';

const CONFIG_GUIDE: string =
  'AI 功能未配置：请将 entry/src/main/resources/rawfile/ai_config.example.json 复制为同目录 ai_config.json 并填入密钥（该文件不入库）';
const BODY_SUMMARY_MAX: number = 160;

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
  question: string;
  knowledgeSummary: string;
  subject: string;
  answerType: string;
  errorType: string;
  knowledgeTags: string[];
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
  knowledgeSummary: string = '';
  subject: Subject = Subject.MATH;
  answerType: AnswerType = AnswerType.TEXT;
  errorType: ErrorType = ErrorType.OTHER;
  tags: string[] = [];
  ok: boolean = false;
  error: string = '';
}

export class AiService {
  private static async ensureConfig(): Promise<void> {
    await AiConfig.load();
    if (!AiConfig.configured) {
      throw new Error(CONFIG_GUIDE);
    }
  }

  static async recognizeImage(imagePath: string, fracs: CropFracs | undefined): Promise<string> {
    const base64: string | undefined = await MediaService.readRegionBase64(imagePath, fracs, 1280);
    if (base64 === undefined || base64.length === 0) {
      throw new Error('图片读取失败，请重新选择图片');
    }
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

  static async summarizeKnowledge(question: string): Promise<string> {
    const prompt: string =
      '请把下面的题目内容总结为一个知识点名称，要求：不超过10个汉字；只输出知识点名称本身；不要标点、不要解释。\n题目：' + question;
    const part: AiContentPart = { type: 'text', text: prompt };
    const raw: string = await AiService.request([{ role: 'user', content: [part] }]);
    return AiService.cleanText(raw);
  }

  static async recognizeQuestion(imagePath: string, fracs: CropFracs | undefined, ocrHint: string): Promise<AiQuestionResult> {
    const base64: string | undefined = await MediaService.readRegionBase64(imagePath, fracs, 1280);
    const textPrompt: string =
      '这是一道错题的图片，附带了OCR初步识别文字作为参考。请结合图片准确识别，并以纯JSON返回（不要markdown代码块、不要解释）。\n' +
      'OCR参考文字：' + (ocrHint.length > 0 ? ocrHint : '（无）') + '\n' +
      '返回格式：{"question":"准确的题目内容","knowledgeSummary":"不超过10个汉字的知识点名称","subject":"math或chinese或english或science","answerType":"choice或numeric或text或subjective","errorType":"concept或careless或misread或other","knowledgeTags":["标签1","标签2"]}\n' +
      'subject 只能是 math/chinese/english/science；answerType 只能是 choice/numeric/text/subjective；errorType 只能是 concept/careless/misread/other。只输出JSON。';
    const parts: AiContentPart[] = [];
    if (base64 !== undefined && base64.length > 0) {
      parts.push({ type: 'image_url', image_url: { url: 'data:image/jpeg;base64,' + base64 } });
    }
    parts.push({ type: 'text', text: textPrompt });
    const raw: string = await AiService.request([{ role: 'user', content: parts }]);
    return AiService.parseQuestion(raw);
  }

  private static parseQuestion(raw: string): AiQuestionResult {
    const result: AiQuestionResult = new AiQuestionResult();
    try {
      const jsonStr: string = AiService.extractJson(raw);
      const obj: AiQuestionRaw = JSON.parse(jsonStr) as AiQuestionRaw;
      result.question = obj.question !== undefined ? obj.question : '';
      result.knowledgeSummary = AiService.cleanText(obj.knowledgeSummary !== undefined ? obj.knowledgeSummary : '');
      result.subject = AiService.mapSubject(obj.subject);
      result.answerType = AiService.mapAnswerType(obj.answerType);
      result.errorType = AiService.mapErrorType(obj.errorType);
      if (obj.knowledgeTags !== undefined) {
        result.tags = obj.knowledgeTags;
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
    return AiService.parseAnalysis(raw);
  }

  private static async request(messages: AiMessage[]): Promise<string> {
    await AiService.ensureConfig();
    const httpRequest: http.HttpRequest = http.createHttp();
    try {
      const bodyObj: Record<string, Object> = {
        'model': AiConfig.model,
        'messages': messages as Object,
        'temperature': 0.1 as Object,
        'max_tokens': 1024 as Object
      };
      const response = await httpRequest.request(AiConfig.baseUrl, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + AiConfig.apiKey },
        extraData: JSON.stringify(bodyObj),
        connectTimeout: 15000,
        readTimeout: 60000
      });
      const bodyStr: string = AiService.responseBodyText(response.result);
      if (response.responseCode !== 200) {
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
