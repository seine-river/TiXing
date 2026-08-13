import { CommunityPostStatus, Grade } from './Enums';

export class CommunityPost {
  id: string = '';
  studentId: string = '';
  mistakeId: string = '';
  redactedImageUrl: string = '';
  knowledgeTagId: string = '';
  grade: Grade = Grade.G3;
  status: CommunityPostStatus = CommunityPostStatus.PENDING_PARENT_CONFIRM;
  parentConfirmedAt: number = 0;
  likeCount: number = 0;
  collectCount: number = 0;
  createdAt: number = 0;
}
