import router from '@ohos.router';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  Spacing,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight,
  ComponentSizes
} from '../../constants/design-tokens';

@Entry
@Component
struct UserAgreement {
  private agreementContent: string = `BuddyJob AI（以下简称"我们"）为用户提供 AI 驱动的求职辅助服务，包括但不限于简历分析、岗位测评、智能对话和求职知识库。本条款构成您与我们之间具有法律约束力的协议。

1. 服务说明
BuddyJob AI 为用户提供 AI 驱动的求职辅助服务，包括但不限于简历分析、岗位测评、智能对话和求职知识库。

2. 用户责任
使用本服务时，您同意：
• 提供真实、准确的个人信息；
• 妥善保管账户凭证，对账户下的所有活动负责；
• 不利用本服务从事违法活动或侵犯他人权益；
• 不尝试通过逆向工程、爬虫等方式获取本服务的底层技术或数据；
• 不干扰或破坏服务的正常运行。

3. 知识产权
本服务的所有内容、功能和界面设计均归 BuddyJob AI 所有，受国际版权、商标和其他知识产权法律保护。未经书面许可，您不得复制、修改、分发或创建衍生作品。您上传的简历内容归您所有，您授予我们仅为提供服务而使用这些内容的许可。

4. 付费服务
• 部分高级功能需要订阅付费会员（Pro 会员）；
• 订阅费用在购买时显示，我们保留调整价格的权利（提前 30 天通知）；
• 订阅自动续费，您可以随时取消；
• 取消订阅后，您可以在当前计费周期结束前继续使用付费功能；
• 退款政策：购买后 7 天内可申请全额退款，之后按剩余天数比例退款。

5. 责任限制
在适用法律允许的最大范围内：
• 本服务按"现状"提供，不作任何明示或暗示的保证；
• AI 生成的内容仅供参考，不构成专业建议（法律、职业、财务等）；
• 我们不对因使用本服务而产生的任何间接、附带、特殊或后果性损害承担责任；
• 我们对 AI 分析结果的准确性和完整性不作保证。

6. 服务终止
• 您可以随时注销账户并停止使用本服务；
• 如果您违反本条款，我们有权暂停或终止您的账户；
• 账户注销后，我们将在 30 天内删除您的个人数据（法律法规要求保留的除外）；
• 服务终止不影响已产生的付费义务。

7. 争议解决
因本条款引起的争议应首先通过友好协商解决。协商不成的，任何一方可将争议提交至有管辖权的法院。本条款受新加坡法律管辖。如本条款的任何条款被认定为无效或不可执行，其余条款仍然有效。

8. 条款变更
我们保留随时修改本条款的权利。重大变更将通过应用内通知或邮件方式提前 30 天告知。修改后的条款在通知期结束后生效。继续使用本服务即表示您同意修改后的条款。

9. 联系我们
如果您对本服务条款有任何疑问，请通过以下方式联系我们：
• 邮箱：legal@buddyjob.ai
• 我们将在 15 个工作日内回复您的请求。

最后更新：2025年5月12日`;

  build() {
    Column() {
      // 标题栏
      Row() {
        Column() {
          Image($r('app.media.ic_arrow_right'))
            .width(20)
            .height(20)
            .fillColor(SemanticColors.Text1)
            .rotate({ angle: 180 })
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          router.back();
        })

        Text('用户协议')
          .fontSize(FontSize.Xl)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.Text1)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 占位保持标题居中
        Column()
          .width(40)
          .height(40)
      }
      .width('100%')
      .height(56)
      .padding({ left: Spacing.Space2, right: SemanticSpacing.Lg })
      .backgroundColor(NeutralColors.Neutral0)
      .shadow({
        radius: 8,
        color: 'rgba(0, 0, 0, 0.04)',
        offsetY: 2
      })

      Scroll() {
        Column() {
          Text(this.agreementContent)
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text2)
            .lineHeight(24)
            .width('100%')
        }
        .width('100%')
        .padding(SemanticSpacing.Xl)
      }
      .layoutWeight(1)
      .backgroundColor(NeutralColors.Neutral50)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(NeutralColors.Neutral50)
  }
}
