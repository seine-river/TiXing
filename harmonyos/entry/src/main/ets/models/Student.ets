import { Grade, TextbookVersion, SubscriptionStatus } from './Enums';

export class Student {
  id: string = '';
  parentId: string = '';
  nickname: string = '';
  grade: Grade = Grade.G3;
  textbookVersion: TextbookVersion = TextbookVersion.PEP;
  region: string = '';
  school: string = '';
  communityBrowseEnabled: boolean = false;
  communityShareEnabled: boolean = false;
  createdAt: number = 0;
}

export class ParentAccount {
  id: string = '';
  phoneHash: string = '';
  subscriptionStatus: SubscriptionStatus = SubscriptionStatus.NONE;
  createdAt: number = 0;
}
