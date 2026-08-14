import http from '@ohos.net.http';
import { Subject, AnswerType } from '../models/Enums';
import { MediaService } from './MediaService';

const API_URL: string = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
const API_KEY: string = '361eb1bf39e0431991e7fbdc9f6c5e47.hu7HsUzUPLbbsxoG';
const MODEL: string = 'glm-4.6v';

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

export class AiAnalysis {
  analysis: string = '';
  answerType: AnswerType = AnswerType.TEXT;
  subject: Subject = Subject.MATH;
  tags: string[] = [];
}

export class AiService {
  static async recognizeImage(imagePath: string): Promise<string> {
    const base64: string | undefined = await MediaService.readImageBase64(imagePath, 1024);
    if (base64 === undefined || base64.length === 0) {
      throw new Error('图片读取失败');
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
    const prompt: string = '请把下面的题目内容总结为一个知识点名称，要求：不超过10个汉字；只输出知识点名称本身；不要标点、不要解释。\n题目：' + question;
    const part: AiContentPart = { type: 'text', text: prompt };
    const raw: string = await AiService.request([{ role: 'user', content: [part] }]);
    return AiService.cleanText(raw);
  }

  static async analyzeMistake(question: string, myAnswer: string, standardAnswer: string): Promise<AiAnalysis> {
    const prompt: string = '请分析以下错题并以纯JSON返回（不要markdown代码块、不要解释）。\n' +
      '题目：' + question + '\n我的答案：' + myAnswer + '\n标准答案：' + standardAnswer + '\n' +
      '返回格式：{"analysis":"简短的错误点分析","answerType":"choice或numeric或text或subjective","subject":"math或chinese或english","knowledgeTags":["标签1","标签2"]}\n' +
      'answerType 只能是 choice/numeric/text/subjective 之一；subject 只能是 math/chinese/english 之一。只输出JSON。';
    const part: AiContentPart = { type: 'text', text: prompt };
    const raw: string = await AiService.request([{ role: 'user', content: [part] }]);
    return AiService.parseAnalysis(raw);
  }

  private static async request(messages: AiMessage[]): Promise<string> {
    const httpRequest: http.HttpRequest = http.createHttp();
    try {
      const bodyObj: Record<string, Object> = {
        'model': MODEL,
        'messages': messages as Object,
        'temperature': 0.1 as Object,
        'max_tokens': 1024 as Object
      };
      const response = await httpRequest.request(API_URL, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + API_KEY },
        extraData: JSON.stringify(bodyObj),
        connectTimeout: 15000,
        readTimeout: 60000
      });
      if (response.responseCode !== 200) {
        throw new Error('AI请求失败: ' + response.responseCode);
      }
      const resultStr: string = typeof response.result === 'string' ? response.result as string : '';
      const respObj: AiResponse = JSON.parse(resultStr) as AiResponse;
      if (respObj.choices === undefined || respObj.choices.length === 0) {
        throw new Error('AI返回为空');
      }
      return respObj.choices[0].message.content;
    } finally {
      httpRequest.destroy();
    }
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
    } catch (e) {
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
    if (s === 'choice') return AnswerType.CHOICE;
    if (s === 'numeric') return AnswerType.NUMERIC;
    if (s === 'subjective') return AnswerType.SUBJECTIVE;
    return AnswerType.TEXT;
  }

  private static mapSubject(s: string): Subject {
    if (s === 'chinese') return Subject.CHINESE;
    if (s === 'english') return Subject.ENGLISH;
    return Subject.MATH;
  }
}
