import { Mistake } from '../models/Mistake';
import { AppColors, AppSizes, subjectLabel, statusLabel, formatDate, toFileUri, truncateText, subjectSoftColor, subjectEmoji } from '../common/Constants';
import { StatusTag, SubjectTag } from './CommonComponents';

/**
 * 错题卡片：学科色条 + 两级标题截断 + 科目/状态标签 + 降采样缩略图。
 */
@Component
export struct MistakeCard {
  @Prop mistake: Mistake = new Mistake();
  onItemClick: (m: Mistake) => void = (_m: Mistake): void => {
  };

  private cardTitle(): string {
    if (this.mistake.knowledgeSummary.length > 0) {
      return this.mistake.knowledgeSummary;
    }
    if (this.mistake.ocrText.length > 0) {
      return truncateText(this.mistake.ocrText, 36);
    }
    return '未命名错题';
  }

  build() {
    Row() {
      // 学科 emoji 气泡（直觉识别）
      Text(subjectEmoji(this.mistake.subject))
        .fontSize(20)
        .width(46)
        .height(46)
        .textAlign(TextAlign.Center)
        .backgroundColor(subjectSoftColor(this.mistake.subject))
        .borderRadius(15)
        .margin({ right: 12 })

      Column() {
        Text(this.cardTitle())
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(22)
          .accessibilityText(this.cardTitle())
        Row({ space: 6 }) {
          SubjectTag({ subjectText: subjectLabel(this.mistake.subject), subjectKey: this.mistake.subject })
          StatusTag({ statusText: statusLabel(this.mistake.status), statusKey: this.mistake.status })
          Text(formatDate(this.mistake.createdAt))
            .fontSize(11)
            .fontColor(AppColors.TEXT_PLACEHOLDER)
        }
        .margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.mistake.imageUrl.length > 0) {
        Image(toFileUri(this.mistake.imageUrl))
          .width(68)
          .height(68)
          .borderRadius(14)
          .objectFit(ImageFit.Cover)
          .sourceSize({ width: 200, height: 200 })
          .margin({ left: 12 })
          .alt($r('app.media.startIcon'))
          .accessibilityText('错题图片')
      } else {
        Column() {
          Text('📷')
            .fontSize(26)
        }
        .width(68)
        .height(68)
        .borderRadius(14)
        .backgroundColor(AppColors.BG_CHIP)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .margin({ left: 12 })
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS_LG)
    .shadow({ radius: 10, color: AppColors.SHADOW_SOFT, offsetY: 3 })
    .onClick(() => {
      this.onItemClick(this.mistake);
    })
  }
}
