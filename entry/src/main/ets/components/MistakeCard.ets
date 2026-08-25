import { Mistake } from '../models/Mistake';
import { AppColors, AppSizes, subjectLabel, statusLabel, formatDate, toFileUri, truncateText } from '../common/Constants';
import { StatusTag, SubjectTag } from './CommonComponents';

/**
 * 错题卡片（T044/FR-023）：两级标题截断 + 科目/状态标签 + 64vp 降采样缩略图（占位）。
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
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.mistake.imageUrl.length > 0) {
        Image(toFileUri(this.mistake.imageUrl))
          .width(64)
          .height(64)
          .borderRadius(AppSizes.CORNER_RADIUS_XS)
          .objectFit(ImageFit.Cover)
          .sourceSize({ width: 200, height: 200 })
          .margin({ left: 10 })
          .alt($r('app.media.startIcon'))
          .accessibilityText('错题图片')
      } else {
        Column() {
          Text('📷')
            .fontSize(28)
        }
        .width(64)
        .height(64)
        .borderRadius(AppSizes.CORNER_RADIUS_XS)
        .backgroundColor(AppColors.BG_CHIP)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .margin({ left: 10 })
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS_SM)
    .shadow({ radius: 6, color: AppColors.SHADOW_SOFT, offsetY: 2 })
    .onClick(() => {
      this.onItemClick(this.mistake);
    })
  }
}
