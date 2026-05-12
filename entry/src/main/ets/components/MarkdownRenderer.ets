/**
 * MarkdownRenderer 组件
 * 使用 RichText 组件渲染 Markdown 内容
 * 支持：标题、加粗、列表、代码块、引用、表格、链接等
 */

import { parseMarkdown, hasMarkdown, MarkdownParseResult } from '../utils/markdown';
import { BrandColors, NeutralColors, SemanticColors, FontSize, FontWeight, Spacing, SemanticSpacing, BorderRadius, SemanticRadius } from '../constants/design-tokens';

@Component
export struct MarkdownRenderer {
  /** Markdown 内容 */
  @Prop content: string = '';
  /** 是否启用流式渲染模式 */
  @Prop streaming: boolean = false;
  /** 最大高度（用于限制渲染区域） */
  @Prop maxHeight: number | undefined = undefined;
  /** 自定义内边距 */
  @Prop padding: Padding | number = { left: 0, right: 0, top: 0, bottom: 0 };
  /** 是否显示加载动画（流式输出时） */
  @State showCursor: boolean = false;
  /** 解析后的 HTML 内容 */
  @State parsedHtml: string = '';
  /** 是否需要解析 Markdown */
  @State needsParsing: boolean = false;

  aboutToAppear() {
    this.updateContent();
    if (this.streaming) {
      this.startCursorAnimation();
    }
  }

  aboutToUpdate() {
    this.updateContent();
  }

  /**
   * 更新解析后的内容
   */
  private updateContent() {
    if (!this.content) {
      this.parsedHtml = '';
      return;
    }

    // 检查是否包含 Markdown 语法
    this.needsParsing = hasMarkdown(this.content);

    if (this.needsParsing) {
      const result = parseMarkdown(this.content);
      this.parsedHtml = this.wrapHtml(result.html);
    } else {
      // 纯文本，使用简单段落包裹
      this.parsedHtml = this.wrapPlainText(this.content);
    }
  }

  /**
   * 包装 HTML 内容，添加基础样式
   */
  private wrapHtml(html: string): string {
    return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      font-size: 14px;
      line-height: 1.6;
      color: ${SemanticColors.Text1};
      background-color: transparent;
      padding: 0;
      margin: 0;
    }
    /* 代码高亮 */
    pre code {
      display: block;
      white-space: pre;
      word-wrap: normal;
      overflow-x: auto;
    }
    /* 链接样式 */
    a:hover {
      text-decoration: underline !important;
    }
    /* 图片样式 */
    img {
      max-width: 100%;
      height: auto;
      border-radius: 8px;
      margin: 12px 0;
    }
    /* 任务列表 */
    input[type="checkbox"] {
      margin-right: 8px;
    }
  </style>
</head>
<body>
  ${html}
  ${this.streaming ? '<span style="display: inline-block; width: 2px; height: 1em; background-color: ' + BrandColors.Brand500 + '; margin-left: 2px; animation: blink 1s infinite;"></span>' : ''}
  <style>
    @keyframes blink {
      0%, 50% { opacity: 1; }
      51%, 100% { opacity: 0; }
    }
  </style>
</body>
</html>`;
  }

  /**
   * 包装纯文本内容
   */
  private wrapPlainText(text: string): string {
    // 将换行符转换为 <br> 标签
    const lines = text.split('\n').map(line => {
      // 转义 HTML 特殊字符
      const escaped = line
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
      return escaped;
    });

    return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      font-size: 14px;
      line-height: 1.6;
      color: ${SemanticColors.Text1};
      background-color: transparent;
      white-space: pre-wrap;
      word-wrap: break-word;
    }
  </style>
</head>
<body>
  ${lines.join('<br>')}
  ${this.streaming ? '<span style="display: inline-block; width: 2px; height: 1em; background-color: ' + BrandColors.Brand500 + '; margin-left: 2px; animation: blink 1s infinite;"></span>' : ''}
  <style>
    @keyframes blink {
      0%, 50% { opacity: 1; }
      51%, 100% { opacity: 0; }
    }
  </style>
</body>
</html>`;
  }

  /**
   * 启动光标动画（流式输出时使用）
   */
  private startCursorAnimation() {
    this.showCursor = true;
  }

  build() {
    Column() {
      RichText(this.parsedHtml)
        .width('100%')
        .height(this.maxHeight ? this.maxHeight : 'auto')
        .padding(this.padding)
        .layoutWeight(1)
    }
    .width('100%')
    .height(this.maxHeight ? this.maxHeight : 'auto')
  }
}

/**
 * 简化的 Markdown 文本组件
 * 用于在不需要完整 RichText 的场景下显示 Markdown 内容
 */
@Component
export struct MarkdownText {
  @Prop content: string = '';
  @Prop fontSize: number = FontSize.Sm;
  @Prop fontColor: string = SemanticColors.Text1;
  @Prop maxLines: number = 0;

  build() {
    Text(this.content)
      .fontSize(this.fontSize)
      .fontColor(this.fontColor)
      .maxLines(this.maxLines)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .lineHeight(22)
  }
}

/**
 * AI 消息气泡中的 Markdown 渲染器
 * 专为聊天场景优化
 */
@Component
export struct ChatMarkdownRenderer {
  @Prop content: string = '';
  @Prop isStreaming: boolean = false;
  @State parsedHtml: string = '';

  aboutToAppear() {
    this.updateParsedContent();
  }

  aboutToUpdate() {
    this.updateParsedContent();
  }

  private updateParsedContent() {
    if (!this.content) {
      this.parsedHtml = '';
      return;
    }

    const result = parseMarkdown(this.content);
    this.parsedHtml = this.wrapForChat(result.html);
  }

  private wrapForChat(html: string): string {
    return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      font-size: 14px;
      line-height: 1.6;
      color: ${SemanticColors.Text1};
      background-color: transparent;
    }
    p { margin: 8px 0; }
    p:first-child { margin-top: 0; }
    p:last-child { margin-bottom: 0; }
    h1, h2, h3, h4, h5, h6 { margin: 12px 0 8px 0; }
    h1:first-child, h2:first-child, h3:first-child { margin-top: 0; }
    ul, ol { margin: 8px 0; padding-left: 20px; }
    li { margin: 4px 0; }
    pre {
      margin: 12px 0;
      border-radius: 8px;
      overflow-x: auto;
    }
    code {
      font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
    }
    blockquote {
      margin: 12px 0;
    }
    table {
      margin: 12px 0;
    }
    hr {
      margin: 16px 0;
    }
    a:hover {
      text-decoration: underline !important;
    }
  </style>
</head>
<body>
  ${html}
  ${this.isStreaming ? '<span style="display: inline-block; width: 2px; height: 1.2em; background-color: ' + BrandColors.Brand500 + '; margin-left: 2px; vertical-align: middle; animation: blink 1s infinite;"></span>' : ''}
  <style>
    @keyframes blink {
      0%, 50% { opacity: 1; }
      51%, 100% { opacity: 0; }
    }
  </style>
</body>
</html>`;
  }

  build() {
    RichText(this.parsedHtml)
      .width('100%')
      .height('auto')
  }
}
