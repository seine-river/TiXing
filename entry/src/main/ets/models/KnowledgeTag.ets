import { Subject, Grade, TextbookVersion, Trend } from './Enums';

export class KnowledgeTag {
  id: string = '';
  subject: Subject = Subject.MATH;
  grade: Grade = Grade.G3;
  textbookVersion: TextbookVersion = TextbookVersion.PEP;
  name: string = '';
  parentTagId: string = '';
}

export class KnowledgeProfile {
  id: string = '';
  studentId: string = '';
  knowledgeTagId: string = '';
  totalMistakes: number = 0;
  masteredCount: number = 0;
  currentMasteryScore: number = 0;
  trend: Trend = Trend.STABLE;
  updatedAt: number = 0;
}
