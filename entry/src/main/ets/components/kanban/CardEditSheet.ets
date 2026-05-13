/**
 * 新增/编辑求职卡片底部弹窗
 */
import {
  JobCard, CardPriority, KanbanColumnStatus,
  DEFAULT_COLUMNS, DEFAULT_TAGS, DEFAULT_SOURCES
} from '../../models/Kanban';
import { Colors } from '../../constants/colors';

@Component
export struct CardEditSheet {
  @Prop isEdit: boolean = false;
  @Prop editCard: JobCard | null = null;
  @Prop defaultColumn: KanbanColumnStatus = KanbanColumnStatus.WISH;

  // 表单字段
  @State company: string = '';
  @State position: string = '';
  @State location: string = '';
  @State salary: string = '';
  @State priority: CardPriority = CardPriority.MEDIUM;
  @State source: string = '';
  @State note: string = '';
  @State columnStatus: KanbanColumnStatus = KanbanColumnStatus.WISH;
  @State selectedTags: string[] = [];
  @State showTagPicker: boolean = false;
  @State showSourcePicker: boolean = false;

  // 回调
  onSave?: (data: {
    company: string;
    position: string;
    location: string;
    salary: string;
    priority: CardPriority;
    source: string;
    note: string;
    columnStatus: KanbanColumnStatus;
    tags: string[];
  }) => void;
  onDelete?: () => void;

  aboutToAppear() {
    if (this.isEdit && this.editCard) {
      this.company = this.editCard.company;
      this.position = this.editCard.position;
      this.location = this.editCard.location || '';
      this.salary = this.editCard.salary || '';
      this.priority = this.editCard.priority;
      this.source = this.editCard.source || '';
      this.note = this.editCard.note || '';
      this.columnStatus = this.editCard.columnStatus;
      this.selectedTags = [...this.editCard.tags];
    } else {
      this.columnStatus = this.defaultColumn;
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text(this.isEdit ? '编辑' : '新增求职')
          .fontSize(18)
          .fontColor(Colors.textPrimary)
          .fontWeight(FontWeight.Medium)

        Blank()

        if (this.isEdit) {
          Text('删除')
            .fontSize(14)
            .fontColor(Colors.error)
            .onClick(() => {
              this.onDelete?.();
            })
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 12 })

      // 表单内容 - 可滚动
      Scroll() {
        Column() {
          // 公司名（必填）
          this.FormInput('公司名称 *', this.company, '请输入公司名称', true, (v) => {
            this.company = v;
          })

          // 职位（必填）
          this.FormInput('职位名称 *', this.position, '请输入职位名称', true, (v) => {
            this.position = v;
          })

          // 所在城市
          this.FormInput('所在城市', this.location, '如：北京、上海、深圳', false, (v) => {
            this.location = v;
          })

          // 薪资范围
          this.FormInput('薪资范围', this.salary, '如：15k-25k', false, (v) => {
            this.salary = v;
          })

          // 来源平台
          Row() {
            Text('来源平台')
              .fontSize(14)
              .fontColor(Colors.textSecondary)
              .width('100%')

            Row() {
              Text(this.source || '请选择')
                .fontSize(14)
                .fontColor(this.source ? Colors.textPrimary : Colors.textPlaceholder)
                .layoutWeight(1)

              Image($r('app.media.media_ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor(Colors.textMuted)
            }
            .width('100%')
            .height(44)
            .backgroundColor(Colors.backgroundSecondary)
            .borderRadius(8)
            .padding({ left: 12, right: 12 })
            .margin({ top: 8 })
            .onClick(() => {
              this.showSourcePicker = true;
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // 优先级
          Row() {
            Text('优先级')
              .fontSize(14)
              .fontColor(Colors.textSecondary)
              .width('100%')

            Row() {
              ForEach([
                { label: '低', value: CardPriority.LOW, color: '#52C41A' },
                { label: '中', value: CardPriority.MEDIUM, color: '#FAAD14' },
                { label: '高', value: CardPriority.HIGH, color: '#FF4D4F' }
              ], (item: { label: string; value: CardPriority; color: string }) => {
                Text(item.label)
                  .fontSize(13)
                  .fontColor(this.priority === item.value ? '#FFFFFF' : Colors.textSecondary)
                  .backgroundColor(this.priority === item.value ? item.color : Colors.backgroundSecondary)
                  .borderRadius(6)
                  .padding({ left: 16, right: 16, top: 6, bottom: 6 })
                  .margin({ right: 8 })
                  .onClick(() => {
                    this.priority = item.value;
                  })
              })
            }
            .width('100%')
            .margin({ top: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // 标签选择
          Row() {
            Text('标签')
              .fontSize(14)
              .fontColor(Colors.textSecondary)
              .width('100%')

            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(DEFAULT_TAGS, (tag: string) => {
                Text(tag)
                  .fontSize(12)
                  .fontColor(this.selectedTags.includes(tag) ? '#FFFFFF' : Colors.textSecondary)
                  .backgroundColor(this.selectedTags.includes(tag) ? Colors.primary : Colors.backgroundSecondary)
                  .borderRadius(4)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .margin({ right: 6, bottom: 6 })
                  .onClick(() => {
                    this.toggleTag(tag);
                  })
              })
            }
            .width('100%')
            .margin({ top: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // 备注
          Row() {
            Text('备注')
              .fontSize(14)
              .fontColor(Colors.textSecondary)
              .width('100%')

            TextArea({ placeholder: '添加备注信息...' })
              .width('100%')
              .height(80)
              .fontSize(14)
              .fontColor(Colors.textPrimary)
              .backgroundColor(Colors.backgroundSecondary)
              .borderRadius(8)
              .padding(12)
              .margin({ top: 8 })
              .onChange((v) => {
                this.note = v;
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // 目标列（仅新增时显示）
          if (!this.isEdit) {
            Row() {
              Text('添加到')
                .fontSize(14)
                .fontColor(Colors.textSecondary)
                .width('100%')

              Row() {
                ForEach(DEFAULT_COLUMNS, (col) => {
                  Text(col.title)
                    .fontSize(12)
                    .fontColor(this.columnStatus === col.status ? '#FFFFFF' : Colors.textSecondary)
                    .backgroundColor(this.columnStatus === col.status ? col.color : Colors.backgroundSecondary)
                    .borderRadius(6)
                    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                    .margin({ right: 6, bottom: 6 })
                    .onClick(() => {
                      this.columnStatus = col.status;
                    })
                })
              }
              .width('100%')
              .margin({ top: 8 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)

      // 底部保存按钮
      Button(this.isEdit ? '保存修改' : '添加')
        .width('90%')
        .height(48)
        .fontSize(16)
        .fontColor('#FFFFFF')
        .backgroundColor(this.company.length > 0 && this.position.length > 0
          ? Colors.primary : Colors.tabInactive)
        .borderRadius(12)
        .margin({ bottom: 24 })
        .enabled(this.company.length > 0 && this.position.length > 0)
        .onClick(() => {
          this.onSave?.({
            company: this.company,
            position: this.position,
            location: this.location,
            salary: this.salary,
            priority: this.priority,
            source: this.source,
            note: this.note,
            columnStatus: this.columnStatus,
            tags: [...this.selectedTags]
          });
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.white)
    .bindSheet($$this.showSourcePicker, this.SourcePickerSheet(), {
      height: '40%',
      dragBar: true,
      backgroundColor: Colors.white
    })
  }

  @Builder
  FormInput(
    label: string,
    value: string,
    placeholder: string,
    required: boolean,
    onChange: (v: string) => void
  ) {
    Row() {
      Text(`${label}`)
        .fontSize(14)
        .fontColor(Colors.textSecondary)
        .width('100%')

      TextInput({ placeholder: placeholder, text: value })
        .width('100%')
        .height(44)
        .fontSize(14)
        .fontColor(Colors.textPrimary)
        .backgroundColor(Colors.backgroundSecondary)
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .margin({ top: 8 })
        .onChange(onChange)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 12 })
  }

  @Builder
  SourcePickerSheet() {
    Column() {
      Text('选择来源平台')
        .fontSize(16)
        .fontColor(Colors.textPrimary)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .padding({ left: 20, bottom: 16 })

      List() {
        ForEach(DEFAULT_SOURCES, (src: string) => {
          ListItem() {
            Row() {
              Text(src)
                .fontSize(15)
                .fontColor(this.source === src ? Colors.primary : Colors.textPrimary)

              Blank()

              if (this.source === src) {
                Image($r('app.media.media_ic_check'))
                  .width(20)
                  .height(20)
                  .fillColor(Colors.primary)
              }
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 14, bottom: 14 })
            .onClick(() => {
              this.source = src;
              this.showSourcePicker = false;
            })
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  private toggleTag(tag: string): void {
    const index = this.selectedTags.indexOf(tag);
    if (index >= 0) {
      this.selectedTags = this.selectedTags.filter((_, i) => i !== index);
    } else {
      this.selectedTags = [...this.selectedTags, tag];
    }
  }
}
