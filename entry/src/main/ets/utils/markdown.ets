/**
 * Markdown 解析工具类
 * 将 Markdown 文本转换为 ArkUI RichText 支持的 HTML 格式
 */

import { BrandColors, NeutralColors, SemanticColors, FontSize, FontWeight } from '../constants/design-tokens';

/**
 * Markdown 解析结果
 */
export interface MarkdownParseResult {
  html: string;
  plainText: string;
}

/**
 * Markdown 样式配置
 */
export interface MarkdownStyles {
  headingColor: string;
  textColor: string;
  codeBackground: string;
  codeColor: string;
  linkColor: string;
  listMarkerColor: string;
  blockquoteBorderColor: string;
  blockquoteBackground: string;
}

/**
 * 默认样式配置
 */
export const defaultMarkdownStyles: MarkdownStyles = {
  headingColor: SemanticColors.Text1,
  textColor: SemanticColors.Text1,
  codeBackground: NeutralColors.Neutral100,
  codeColor: BrandColors.Brand600,
  linkColor: BrandColors.Brand500,
  listMarkerColor: BrandColors.Brand500,
  blockquoteBorderColor: BrandColors.Brand300,
  blockquoteBackground: BrandColors.Brand50
};

/**
 * 转义 HTML 特殊字符
 */
function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

/**
 * 解析行内样式（加粗、斜体、行内代码、链接）
 */
function parseInline(text: string): string {
  // 行内代码 `code`
  text = text.replace(/`([^`]+)`/g, `<code style="
    background-color: ${defaultMarkdownStyles.codeBackground};
    color: ${defaultMarkdownStyles.codeColor};
    padding: 2px 6px;
    border-radius: 4px;
    font-family: monospace;
    font-size: 0.9em;
  ">$1</code>`);

  // 加粗 **text** 或 __text__
  text = text.replace(/\*\*([^*]+)\*\*|__([^_]+)__/g, `<strong style="font-weight: ${FontWeight.Bold};">$1$2</strong>`);

  // 斜体 *text* 或 _text_
  text = text.replace(/\*([^*]+)\*|_([^_]+)_/g, `<em style="font-style: italic;">$1$2</em>`);

  // 删除线 ~~text~~
  text = text.replace(/~~([^~]+)~~/g, `<del style="text-decoration: line-through;">$1</del>`);

  // 链接 [text](url)
  text = text.replace(/\[([^\]]+)\]\(([^)]+)\)/g, `<a href="$2" style="
    color: ${defaultMarkdownStyles.linkColor};
    text-decoration: none;
  ">$1</a>`);

  return text;
}

/**
 * 解析代码块
 */
function parseCodeBlock(content: string, language?: string): string {
  const escapedContent = escapeHtml(content);
  return `<pre style="
    background-color: ${NeutralColors.Neutral900};
    color: ${NeutralColors.Neutral50};
    padding: 16px;
    border-radius: 8px;
    overflow-x: auto;
    margin: 12px 0;
    font-family: monospace;
    font-size: 14px;
    line-height: 1.5;
  "><code${language ? ` class="language-${language}"` : ''}>${escapedContent}</code></pre>`;
}

/**
 * 解析引用块
 */
function parseBlockquote(lines: string[]): string {
  const content = lines.join('\n').replace(/^>\s?/gm, '');
  const parsedContent = parseMarkdown(content).html;
  return `<blockquote style="
    border-left: 4px solid ${defaultMarkdownStyles.blockquoteBorderColor};
    background-color: ${defaultMarkdownStyles.blockquoteBackground};
    padding: 12px 16px;
    margin: 12px 0;
    border-radius: 0 8px 8px 0;
  ">${parsedContent}</blockquote>`;
}

/**
 * 解析列表
 */
function parseList(lines: string[], isOrdered: boolean): string {
  const items: string[] = [];
  let currentItem: string[] = [];
  let indentLevel = 0;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const match = line.match(/^(\s*)([-*+]|\d+\.)\s+(.*)$/);
    if (match) {
      if (currentItem.length > 0) {
        items.push(parseInline(currentItem.join('\n')));
        currentItem = [];
      }
      currentItem.push(match[3]);
      indentLevel = match[1].length;
    } else if (line.trim() === '') {
      if (currentItem.length > 0) {
        items.push(parseInline(currentItem.join('\n')));
        currentItem = [];
      }
    } else {
      currentItem.push(line.trim());
    }
  }

  if (currentItem.length > 0) {
    items.push(parseInline(currentItem.join('\n')));
  }

  const listStyle = isOrdered ? 'decimal' : 'disc';
  const tag = isOrdered ? 'ol' : 'ul';

  const itemsHtml = items.map(item => `<li style="
    margin: 8px 0;
    line-height: 1.6;
  ">${item}</li>`).join('');

  return `<${tag} style="
    padding-left: 24px;
    margin: 12px 0;
    list-style-type: ${listStyle};
    color: ${defaultMarkdownStyles.listMarkerColor};
  ">${itemsHtml}</${tag}>`;
}

/**
 * 解析表格
 */
function parseTable(lines: string[]): string {
  if (lines.length < 2) return '';

  // 解析表头
  const headers = lines[0].split('|').map(h => h.trim()).filter(h => h);

  // 跳过分隔行
  const dataRows = lines.slice(2);

  const headerHtml = headers.map(h => `<th style="
    background-color: ${NeutralColors.Neutral100};
    padding: 12px;
    text-align: left;
    font-weight: ${FontWeight.Semibold};
    border-bottom: 2px solid ${NeutralColors.Neutral200};
  ">${parseInline(h)}</th>`).join('');

  const rowsHtml = dataRows.map(row => {
    const cells = row.split('|').map(c => c.trim()).filter(c => c);
    return `<tr>${cells.map(c => `<td style="
      padding: 12px;
      border-bottom: 1px solid ${NeutralColors.Neutral200};
    ">${parseInline(c)}</td>`).join('')}</tr>`;
  }).join('');

  return `<table style="
    width: 100%;
    border-collapse: collapse;
    margin: 16px 0;
    font-size: 14px;
  "><thead><tr>${headerHtml}</tr></thead><tbody>${rowsHtml}</tbody></table>`;
}

/**
 * 解析标题
 */
function parseHeading(text: string, level: number): string {
  const fontSize = level === 1 ? FontSize.Xxl :
                   level === 2 ? FontSize.Xl :
                   level === 3 ? FontSize.Lg :
                   level === 4 ? FontSize.Base :
                   FontSize.Sm;

  const marginTop = level === 1 ? '24px' : level === 2 ? '20px' : '16px';
  const marginBottom = '12px';

  return `<h${level} style="
    color: ${defaultMarkdownStyles.headingColor};
    font-size: ${fontSize}px;
    font-weight: ${FontWeight.Bold};
    margin: ${marginTop} 0 ${marginBottom} 0;
    line-height: 1.3;
  ">${parseInline(text)}</h${level}>`;
}

/**
 * 解析段落
 */
function parseParagraph(text: string): string {
  if (!text.trim()) return '';
  return `<p style="
    color: ${defaultMarkdownStyles.textColor};
    line-height: 1.6;
    margin: 12px 0;
    font-size: ${FontSize.Sm}px;
  ">${parseInline(text)}</p>`;
}

/**
 * 解析分隔线
 */
function parseHorizontalRule(): string {
  return `<hr style="
    border: none;
    border-top: 1px solid ${NeutralColors.Neutral200};
    margin: 24px 0;
  " />`;
}

/**
 * 主解析函数
 */
export function parseMarkdown(markdown: string): MarkdownParseResult {
  if (!markdown || markdown.trim() === '') {
    return { html: '', plainText: '' };
  }

  const lines = markdown.split('\n');
  const result: string[] = [];
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];

    // 代码块 ```language
    if (line.startsWith('```')) {
      const language = line.slice(3).trim();
      const codeLines: string[] = [];
      i++;
      while (i < lines.length && !lines[i].startsWith('```')) {
        codeLines.push(lines[i]);
        i++;
      }
      result.push(parseCodeBlock(codeLines.join('\n'), language));
      i++;
      continue;
    }

    // 标题 # Heading
    const headingMatch = line.match(/^(#{1,6})\s+(.+)$/);
    if (headingMatch) {
      const level = headingMatch[1].length;
      result.push(parseHeading(headingMatch[2], level));
      i++;
      continue;
    }

    // 引用块 > text
    if (line.startsWith('>')) {
      const quoteLines: string[] = [];
      while (i < lines.length && (lines[i].startsWith('>') || (lines[i].trim() === '' && quoteLines.length > 0))) {
        quoteLines.push(lines[i]);
        i++;
      }
      result.push(parseBlockquote(quoteLines));
      continue;
    }

    // 无序列表 - item 或 * item 或 + item
    if (line.match(/^\s*[-*+]\s+/)) {
      const listLines: string[] = [];
      while (i < lines.length && (lines[i].match(/^\s*[-*+]\s+/) || lines[i].trim() === '' || (lines[i].startsWith('  ') && listLines.length > 0))) {
        listLines.push(lines[i]);
        i++;
      }
      result.push(parseList(listLines, false));
      continue;
    }

    // 有序列表 1. item
    if (line.match(/^\s*\d+\.\s+/)) {
      const listLines: string[] = [];
      while (i < lines.length && (lines[i].match(/^\s*\d+\.\s+/) || lines[i].trim() === '' || (lines[i].startsWith('  ') && listLines.length > 0))) {
        listLines.push(lines[i]);
        i++;
      }
      result.push(parseList(listLines, true));
      continue;
    }

    // 表格 | col1 | col2 |
    if (line.includes('|') && i + 1 < lines.length && lines[i + 1].includes('|')) {
      const tableLines: string[] = [];
      while (i < lines.length && lines[i].includes('|')) {
        tableLines.push(lines[i]);
        i++;
      }
      result.push(parseTable(tableLines));
      continue;
    }

    // 分隔线 --- 或 *** 或 ___
    if (line.match(/^\s*([-*_])\s*\1\s*\1\s*$/)) {
      result.push(parseHorizontalRule());
      i++;
      continue;
    }

    // 普通段落
    if (line.trim()) {
      const paragraphLines: string[] = [line];
      i++;
      while (i < lines.length && lines[i].trim() && !lines[i].match(/^[#>|\-*\d]/)) {
        paragraphLines.push(lines[i]);
        i++;
      }
      result.push(parseParagraph(paragraphLines.join(' ')));
    } else {
      i++;
    }
  }

  // 生成纯文本版本（用于预览或搜索）
  const plainText = markdown
    .replace(/```[\s\S]*?```/g, '[代码块]')
    .replace(/`([^`]+)`/g, '$1')
    .replace(/\*\*([^*]+)\*\*/g, '$1')
    .replace(/__([^_]+)__/g, '$1')
    .replace(/\*([^*]+)\*/g, '$1')
    .replace(/_([^_]+)_/g, '$1')
    .replace(/~~([^~]+)~~/g, '$1')
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
    .replace(/^#{1,6}\s+/gm, '')
    .replace(/^>\s?/gm, '')
    .replace(/^\s*[-*+]\s+/gm, '• ')
    .replace(/^\s*\d+\.\s+/gm, '$&. ')
    .trim();

  return {
    html: result.join('\n'),
    plainText
  };
}

/**
 * 检查文本是否包含 Markdown 语法
 */
export function hasMarkdown(text: string): boolean {
  const markdownPatterns = [
    /^#{1,6}\s+/m,           // 标题
    /\*\*[^*]+\*\*/,         // 加粗
    /\*[^*]+\*/,             // 斜体
    /`[^`]+`/,               // 行内代码
    /^```/m,                 // 代码块
    /^>\s?/m,                // 引用
    /^\s*[-*+]\s+/m,         // 无序列表
    /^\s*\d+\.\s+/m,         // 有序列表
    /\[([^\]]+)\]\([^)]+\)/, // 链接
    /~~[^~]+~~/,             // 删除线
    /^\s*([-*_])\s*\1\s*\1\s*$/m  // 分隔线
  ];

  return markdownPatterns.some(pattern => pattern.test(text));
}

/**
 * 获取纯文本预览（前 N 个字符）
 */
export function getPlainTextPreview(markdown: string, maxLength: number = 100): string {
  const { plainText } = parseMarkdown(markdown);
  if (plainText.length <= maxLength) {
    return plainText;
  }
  return plainText.substring(0, maxLength) + '...';
}
