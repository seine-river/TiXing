export enum RedeemableCategory {
  AVATAR = 'avatar',
  COVER = 'cover',
  TITLE = 'title',
  TREE = 'tree'
}

export class RedeemableItem {
  id: string = '';
  name: string = '';
  category: RedeemableCategory = RedeemableCategory.AVATAR;
  cost: number = 0;
  icon: string = '';
  owned: boolean = false;
}
