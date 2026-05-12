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
struct PrivacyPolicy {
  private privacyContent: string = `BuddyJob AI（以下简称"我们"）重视您的隐私保护。本隐私政策说明了我们如何收集、使用、存储和保护您的个人信息。使用我们的服务即表示您同意本隐私政策中描述的做法。

1. 概述
BuddyJob AI（以下简称"我们"）重视您的隐私保护。本隐私政策说明了我们如何收集、使用、存储和保护您的个人信息。使用我们的服务即表示您同意本隐私政策中描述的做法。

2. 信息收集
我们收集您直接提供的信息，包括：
账户信息：姓名、邮箱地址、手机号码（经哈希处理）；
简历数据：您上传的简历文档内容，用于 AI 分析服务；
使用数据：登录/登出时间、页面访问记录、设备标识符（经哈希处理）；
支付信息：我们不存储完整的支付卡号，支付处理由第三方支付服务商完成。

3. 信息使用
您的信息用于以下目的：
• 提供和改进 AI 求职助手服务（简历分析、岗位测评、智能对话）；
• 个性化推荐和用户体验优化；
• 账户安全和身份验证；
• 服务统计和产品迭代分析；
• 遵守法律法规要求。
我们不会将您的个人信息出售给第三方。

4. 信息共享
除以下情况外，我们不会与第三方共享您的个人信息：
• 服务提供商：AI 模型服务商（仅传输必要的分析数据）、云服务提供商；
• 法律要求：根据适用法律法规、法院命令或政府要求；
• 业务转让：在合并、收购或资产出售时，我们会通知您并保护您的数据。

5. 数据存储与安全
• 存储位置：数据存储在安全的云服务器上，可能位于您所在地区之外；
• 存储期限：我们在实现收集目的所需的期限内保留您的数据，账户注销后 30 天内删除所有个人数据；
• 安全措施：采用 HTTPS 加密传输、JWT Token 认证、访问控制等安全措施；
• 数据最小化：仅收集提供服务所必需的最少信息。

6. 您的权利
根据适用的数据保护法律（包括 GDPR 和个人信息保护法），您享有以下权利：
• 访问权：查看我们持有的您的个人信息；
• 更正权：更正不准确的个人信息；
• 删除权：请求删除您的个人信息；
• 导出权：以可读格式导出您的数据；
• 撤回同意：撤回之前给予的任何同意。
如需行使上述权利，请通过 privacy@buddyjob.ai 联系我们。

7. Cookie 政策
我们使用以下类型的 Cookie：
• 必要 Cookie：用于身份验证和会话管理（JWT Token）；
• 功能 Cookie：记住您的语言偏好和设置；
• 分析 Cookie：收集匿名使用统计数据用于产品优化。
您可以通过浏览器设置管理或删除 Cookie。

8. 未成年人保护
我们的服务不面向 16 岁以下的未成年人。我们不会故意收集未成年人的个人信息。如果我们发现无意中收集了未成年人的数据，将立即删除。

9. 政策变更
我们可能会不时更新本隐私政策。重大变更将通过应用内通知或邮件方式告知您。继续使用我们的服务即表示您同意修改后的隐私政策。建议您定期查阅本政策。

10. 联系我们
如果您对本隐私政策有任何疑问或建议，请通过以下方式联系我们：
• 邮箱：privacy@buddyjob.ai
• 我们将在 30 个工作日内回复您的请求。

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

        Text('隐私政策')
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
          Text(this.privacyContent)
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
