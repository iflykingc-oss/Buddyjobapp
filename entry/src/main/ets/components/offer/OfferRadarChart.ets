/**
 * Offer 雷达图组件
 *
 * 使用 Canvas 2D 绘制雷达图，支持多组数据叠加对比。
 * 使用 design-tokens 的颜色和字体常量。
 */

import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  InfoColors,
  WarningColors,
  SemanticSpacing,
  FontSize,
} from '../../constants/design-tokens';

@Component
export struct OfferRadarChart {
  /** 多组数据，每组5个维度值 */
  @Prop scores: number[][] = [];
  /** 维度名称 */
  @Prop labels: string[] = [];
  /** 每组数据颜色，默认 [Brand500, Info500, Warning500] */
  @Prop dataColors: string[] = [BrandColors.Brand500, InfoColors.Info500, WarningColors.Warning500];

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  /** 将 hex 颜色转为带透明度的 rgba */
  private hexToRgba(hex: string, alpha: number): string {
    const r = parseInt(hex.slice(1, 3), 16);
    const g = parseInt(hex.slice(3, 5), 16);
    const b = parseInt(hex.slice(5, 7), 16);
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }

  /** 绘制雷达图网格 */
  private drawRadarGrid(
    ctx: CanvasRenderingContext2D,
    centerX: number,
    centerY: number,
    maxRadius: number,
    sides: number,
    levels: number
  ) {
    const angleStep = (Math.PI * 2) / sides;

    // 绘制多层同心多边形
    for (let level = 1; level <= levels; level++) {
      const r = (maxRadius / levels) * level;
      ctx.beginPath();
      for (let i = 0; i <= sides; i++) {
        const angle = angleStep * i - Math.PI / 2;
        const x = centerX + r * Math.cos(angle);
        const y = centerY + r * Math.sin(angle);
        if (i === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      }
      ctx.closePath();
      ctx.strokeStyle = level === levels ? NeutralColors.Neutral300 : NeutralColors.Neutral200;
      ctx.lineWidth = level === levels ? 1.5 : 0.8;
      ctx.stroke();
    }

    // 绘制轴线 - 从中心到各顶点
    for (let i = 0; i < sides; i++) {
      const angle = angleStep * i - Math.PI / 2;
      ctx.beginPath();
      ctx.moveTo(centerX, centerY);
      ctx.lineTo(centerX + maxRadius * Math.cos(angle), centerY + maxRadius * Math.sin(angle));
      ctx.strokeStyle = NeutralColors.Neutral200;
      ctx.lineWidth = 0.8;
      ctx.stroke();
    }
  }

  /** 绘制数据区域 */
  private drawDataArea(
    ctx: CanvasRenderingContext2D,
    centerX: number,
    centerY: number,
    maxRadius: number,
    sides: number,
    values: number[],
    color: string
  ) {
    const angleStep = (Math.PI * 2) / sides;

    ctx.beginPath();
    for (let i = 0; i <= sides; i++) {
      const idx = i % sides;
      const angle = angleStep * idx - Math.PI / 2;
      const score = Math.min(values[idx] || 0, 100);
      const r = (score / 100) * maxRadius;
      const x = centerX + r * Math.cos(angle);
      const y = centerY + r * Math.sin(angle);
      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.closePath();

    // 填充区域
    ctx.fillStyle = this.hexToRgba(color, 0.2);
    ctx.fill();

    // 描边
    ctx.strokeStyle = color;
    ctx.lineWidth = 2;
    ctx.stroke();

    // 绘制数据点
    for (let i = 0; i < sides; i++) {
      const angle = angleStep * i - Math.PI / 2;
      const score = Math.min(values[i] || 0, 100);
      const r = (score / 100) * maxRadius;
      const x = centerX + r * Math.cos(angle);
      const y = centerY + r * Math.sin(angle);

      ctx.beginPath();
      ctx.arc(x, y, 4, 0, Math.PI * 2);
      ctx.fillStyle = color;
      ctx.fill();
      ctx.strokeStyle = NeutralColors.Neutral0;
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }
  }

  /** 绘制标签 */
  private drawLabels(
    ctx: CanvasRenderingContext2D,
    centerX: number,
    centerY: number,
    maxRadius: number,
    labels: string[],
    sides: number
  ) {
    const angleStep = (Math.PI * 2) / sides;
    const labelRadius = maxRadius + SemanticSpacing.Xxl;

    ctx.font = `${FontSize.Xs}px sans-serif`;
    ctx.fillStyle = NeutralColors.Neutral700;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    for (let i = 0; i < sides; i++) {
      const angle = angleStep * i - Math.PI / 2;
      const x = centerX + labelRadius * Math.cos(angle);
      const y = centerY + labelRadius * Math.sin(angle);
      ctx.fillText(labels[i] || '', x, y);
    }
  }

  /** 主绘制方法 */
  private drawChart() {
    const ctx = this.context;
    const width = 300;
    const height = 300;
    const centerX = width / 2;
    const centerY = height / 2;
    const maxRadius = 100;
    const sides = this.labels.length;
    const levels = 5;

    if (sides === 0) return;

    ctx.clearRect(0, 0, width, height);

    // 1. 绘制网格
    this.drawRadarGrid(ctx, centerX, centerY, maxRadius, sides, levels);

    // 2. 绘制标签
    this.drawLabels(ctx, centerX, centerY, maxRadius, this.labels, sides);

    // 3. 绘制各组数据
    for (let s = 0; s < this.scores.length; s++) {
      const color = this.dataColors[s % this.dataColors.length];
      this.drawDataArea(ctx, centerX, centerY, maxRadius, sides, this.scores[s], color);
    }
  }

  build() {
    Column() {
      Canvas(this.context)
        .width(300)
        .height(300)
        .onReady(() => {
          this.drawChart();
        })
        .onVisibleAreaChange((isVisible: boolean) => {
          if (isVisible) {
            this.drawChart();
          }
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
