/**
 * DarkReader Content Script - 核心渲染引擎
 *
 * 执行时机: document_start（DOM 加载前）
 * 核心目标:
 *   1. 防闪白：立即注入基础暗色样式，覆盖浏览器默认白色背景
 *   2. 智能调色：解析网页颜色，保留色调，仅调整亮度和对比度
 *   3. 动态适配：MutationObserver 处理 SPA 和动态加载内容
 *   4. SPA 路由：监听 history API 和 hash 变化，保证路由跳转无闪白
 *
 * 技术难点说明：
 *   - document_start 时 document.head 可能为 null，始终使用 document.documentElement 兜底
 *   - MutationObserver 使用 12ms 防抖避免 CPU 过载
 *   - CSS Variables 驱动主题切换，无需重新解析 DOM
 *   - 图片/媒体元素用 brightness() 滤镜而非颜色反转
 */

(function () {
  'use strict';

  // ============================================================
  // 第一步：立即注入防闪白基础样式（同步执行，≤5ms）
  // 这是最高优先级操作，必须在任何异步操作之前完成
  // ============================================================

  // 硬编码默认暗色值（不依赖外部配置，确保最快速注入）
  const FALLBACK_BG = '#1e1e1e';
  const FALLBACK_TEXT = '#e0e0e0';

  const flashStyle = document.createElement('style');
  flashStyle.id = '__dr_flash__';
  flashStyle.textContent = `
    html, body {
      background-color: ${FALLBACK_BG} !important;
      color: ${FALLBACK_TEXT} !important;
    }
  `;
  // document_start 时 head 可能还不存在，使用 documentElement 作为兜底
  (document.head || document.documentElement).prepend(flashStyle);

  // ============================================================
  // 运行时状态
  // ============================================================

  let currentTheme = null;      // 当前生效的主题配置
  let currentConfig = null;     // 全局配置（mode、siteRules 等）
  let isActive = false;         // 深色模式是否处于激活状态
  let isPaused = false;         // 用户手动暂停（一键暂停功能）
  let mutationObserver = null;  // DOM 变化监听器
  let debounceTimer = null;     // 防抖计时器
  let originalPushState = null; // 保存原始 history.pushState

  // ============================================================
  // 工具函数：颜色解析与转换
  // ============================================================

  /**
   * 解析 CSS 颜色字符串为 RGBA 对象
   * 支持: rgb(r,g,b) / rgba(r,g,b,a) / #rrggbb / #rgb
   */
  function parseColor(colorStr) {
    if (!colorStr || colorStr === 'transparent' || colorStr === 'inherit' || colorStr === 'initial') {
      return null;
    }

    // rgb/rgba 格式
    let match = colorStr.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([\d.]+))?\s*\)/);
    if (match) {
      return {
        r: parseInt(match[1]),
        g: parseInt(match[2]),
        b: parseInt(match[3]),
        a: match[4] !== undefined ? parseFloat(match[4]) : 1
      };
    }

    // hex 格式
    match = colorStr.match(/^#([0-9a-fA-F]{3,8})$/);
    if (match) {
      let hex = match[1];
      if (hex.length === 3) hex = hex.split('').map(c => c + c).join('');
      if (hex.length === 6) hex = hex + 'ff';
      const int = parseInt(hex, 16);
      return {
        r: (int >> 24) & 0xFF,
        g: (int >> 16) & 0xFF,
        b: (int >> 8)  & 0xFF,
        a: (int        & 0xFF) / 255
      };
    }

    return null;
  }

  /**
   * RGB → HSL 转换
   * @returns {{ h: number, s: number, l: number }} h:0-360, s:0-100, l:0-100
   */
  function rgbToHsl(r, g, b) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b);
    let h = 0, s = 0;
    const l = (max + min) / 2;

    if (max !== min) {
      const d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      switch (max) {
        case r: h = ((g - b) / d + (g < b ? 6 : 0)) / 6; break;
        case g: h = ((b - r) / d + 2) / 6; break;
        case b: h = ((r - g) / d + 4) / 6; break;
      }
    }

    return { h: h * 360, s: s * 100, l: l * 100 };
  }

  /**
   * HSL → RGB 转换
   * @param h 0-360, s 0-100, l 0-100
   * @returns {{ r, g, b }} 0-255
   */
  function hslToRgb(h, s, l) {
    h /= 360; s /= 100; l /= 100;

    if (s === 0) {
      const v = Math.round(l * 255);
      return { r: v, g: v, b: v };
    }

    const hue2rgb = (p, q, t) => {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    };

    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;

    return {
      r: Math.round(hue2rgb(p, q, h + 1 / 3) * 255),
      g: Math.round(hue2rgb(p, q, h) * 255),
      b: Math.round(hue2rgb(p, q, h - 1 / 3) * 255)
    };
  }

  /**
   * 计算 WCAG 相对亮度
   * @returns 0（最暗）到 1（最亮）
   */
  function relativeLuminance(r, g, b) {
    const toLinear = c => {
      const v = c / 255;
      return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    };
    return 0.2126 * toLinear(r) + 0.7152 * toLinear(g) + 0.0722 * toLinear(b);
  }

  /**
   * 计算两色对比度（WCAG 标准，AA 要求 ≥4.5:1）
   */
  function contrastRatio(l1, l2) {
    const lighter = Math.max(l1, l2);
    const darker  = Math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /**
   * 将 rgba 对象转为 CSS 字符串
   */
  function rgbaToCSS({ r, g, b, a = 1 }) {
    return a >= 1 ? `rgb(${r},${g},${b})` : `rgba(${r},${g},${b},${a.toFixed(3)})`;
  }

  // ============================================================
  // 核心色彩调整算法
  // ============================================================

  /**
   * 调整背景色（降低亮度，保留色调）
   * 目标：亮度 L < 25%，深色背景
   */
  function darkenBackground(rgba, targetLightness = 15) {
    if (!rgba || rgba.a < 0.05) return null; // 接近透明，跳过

    const { h, s, l } = rgbToHsl(rgba.r, rgba.g, rgba.b);

    // 如果已经是深色（L < 35%），仅微调
    const newL = l < 35 ? l * 0.7 : targetLightness;
    // 保留色相，略微降低饱和度（避免颜色过于鲜艳）
    const newS = Math.min(s, s * 0.85);

    const newRgb = hslToRgb(h, newS, newL);
    return { ...newRgb, a: rgba.a };
  }

  /**
   * 调整文本色（提升亮度，确保对比度 ≥4.5:1）
   * 目标：亮度 L ≥ 70%，保留色调
   */
  function lightenText(rgba, bgRgba) {
    if (!rgba || rgba.a < 0.05) return null;

    const { h, s, l } = rgbToHsl(rgba.r, rgba.g, rgba.b);

    let newL = Math.max(l, 70);
    let newRgb = hslToRgb(h, s, newL);

    // WCAG 对比度校验：若不达标则继续提升亮度
    if (bgRgba) {
      const bgLum = relativeLuminance(bgRgba.r, bgRgba.g, bgRgba.b);
      let attempts = 0;
      while (attempts < 5) {
        const textLum = relativeLuminance(newRgb.r, newRgb.g, newRgb.b);
        if (contrastRatio(bgLum, textLum) >= 4.5) break;
        newL = Math.min(newL + 5, 95);
        newRgb = hslToRgb(h, s, newL);
        attempts++;
      }
    }

    return { ...newRgb, a: rgba.a };
  }

  // ============================================================
  // CSS 样式生成
  // ============================================================

  /**
   * 根据主题配置生成完整的深色 CSS
   * 使用 CSS Variables 驱动，方便主题切换时只更新变量即可
   */
  function generateDarkCSS(theme) {
    const {
      backgroundColor,
      textColor,
      secondaryTextColor,
      linkColor,
      borderColor,
      dimImages
    } = theme;

    let css = `
/* ===== DarkReader 深色主题 ===== */
/* 主题变量定义 */
:root,
:root *,
html[data-darkreader] {
  --dr-bg: ${backgroundColor};
  --dr-text: ${textColor};
  --dr-text-secondary: ${secondaryTextColor || '#999999'};
  --dr-link: ${linkColor};
  --dr-border: ${borderColor || '#444444'};
  --dr-input-bg: color-mix(in srgb, ${backgroundColor} 80%, white 20%);
  --dr-card-bg: color-mix(in srgb, ${backgroundColor} 85%, white 15%);
  --dr-overlay: rgba(0, 0, 0, 0.6);
}

/* ── 全局基础 ── */
html, body {
  background-color: var(--dr-bg) !important;
  color: var(--dr-text) !important;
}

/* ── 常见容器（div/section/article/header 等） ── */
div, section, article, aside, header, footer, main, nav,
p, span, li, dt, dd, blockquote, figcaption, label, legend,
[class*="container"], [class*="wrapper"], [class*="content"],
[class*="card"], [class*="panel"], [class*="box"] {
  background-color: var(--dr-bg) !important;
  color: var(--dr-text) !important;
  border-color: var(--dr-border) !important;
}

/* ── 标题 ── */
h1, h2, h3, h4, h5, h6 {
  color: var(--dr-text) !important;
}

/* ── 链接 ── */
a {
  color: var(--dr-link) !important;
}
a:hover {
  opacity: 0.85;
}
a:visited {
  color: color-mix(in srgb, var(--dr-link) 75%, purple 25%) !important;
}

/* ── 表单元素（保留可交互感，谨慎使用 !important） ── */
input:not([type="checkbox"]):not([type="radio"]):not([type="range"]),
textarea,
select {
  background-color: var(--dr-input-bg) !important;
  color: var(--dr-text) !important;
  border-color: var(--dr-border) !important;
  caret-color: var(--dr-text) !important;
}

input::placeholder, textarea::placeholder {
  color: var(--dr-text-secondary) !important;
  opacity: 0.7;
}

/* ── 按钮（保留原始背景色，仅调整文字） ── */
button, [role="button"], [type="submit"], [type="button"] {
  color: var(--dr-text) !important;
}

/* ── 表格 ── */
table, th, td {
  border-color: var(--dr-border) !important;
}
th {
  background-color: var(--dr-card-bg) !important;
  color: var(--dr-text) !important;
}
tr:nth-child(even) td {
  background-color: color-mix(in srgb, var(--dr-bg) 95%, white 5%) !important;
}

/* ── 代码块 ── */
code, pre, kbd, samp {
  background-color: var(--dr-card-bg) !important;
  color: var(--dr-text) !important;
  border-color: var(--dr-border) !important;
}

/* ── 水平分割线 ── */
hr {
  border-color: var(--dr-border) !important;
  opacity: 0.5;
}

/* ── 滚动条（WebKit） ── */
::-webkit-scrollbar {
  background-color: var(--dr-bg) !important;
}
::-webkit-scrollbar-thumb {
  background-color: var(--dr-border) !important;
  border-radius: 4px;
}
::-webkit-scrollbar-track {
  background-color: var(--dr-bg) !important;
}

/* ── 遮罩层/模态框 ── */
[class*="modal"], [class*="dialog"], [class*="popup"], [class*="overlay"],
[role="dialog"], [role="alertdialog"] {
  background-color: var(--dr-bg) !important;
  color: var(--dr-text) !important;
}

/* ── 阴影调整（避免深色背景上的亮色阴影） ── */
* {
  box-shadow: none !important;
  text-shadow: none !important;
}
`;

    // 图片暗化（通过 brightness 滤镜，不反色）
    if (dimImages) {
      css += `
/* ── 图片/媒体亮度降低（保留细节，不反色） ── */
img:not([src*="data:image/svg"]),
video,
canvas:not([class*="chart"]):not([class*="graph"]) {
  filter: brightness(0.75) !important;
  -webkit-filter: brightness(0.75) !important;
}

/* SVG 图标稍微暗化，保留可读性 */
svg {
  filter: brightness(0.85) !important;
}
`;
    }

    return css;
  }

  // ============================================================
  // 样式注入与移除
  // ============================================================

  /** 注入完整深色样式（替换已有的完整样式） */
  function injectFullStyle(theme) {
    removeStyleById('__dr_full__');

    const style = document.createElement('style');
    style.id = '__dr_full__';
    style.textContent = generateDarkCSS(theme);
    (document.head || document.documentElement).appendChild(style);

    // 移除防闪白的临时样式（完整样式已覆盖）
    removeStyleById('__dr_flash__');

    isActive = true;
  }

  /** 移除所有 DarkReader 注入的样式，恢复网页原始外观 */
  function removeAllStyles() {
    ['__dr_flash__', '__dr_full__'].forEach(removeStyleById);
    isActive = false;
  }

  function removeStyleById(id) {
    document.getElementById(id)?.remove();
  }

  // ============================================================
  // 配置读取（与 background.js 通信）
  // ============================================================

  /** 从 background.js 读取配置，超时则使用默认值 */
  async function loadConfig() {
    const TIMEOUT_MS = 800; // 超过 800ms 视为失败，使用默认值

    try {
      const result = await Promise.race([
        browser.runtime.sendMessage({ action: 'getConfig', domain: currentDomain() }),
        new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), TIMEOUT_MS))
      ]);

      if (result && result.theme) {
        currentTheme = result.theme;
        currentConfig = result.config;
        return true;
      }
    } catch (e) {
      console.warn('[DarkReader] 配置读取失败，使用默认值:', e.message);
    }

    // 降级默认值
    currentTheme = {
      backgroundColor: FALLBACK_BG,
      textColor: FALLBACK_TEXT,
      secondaryTextColor: '#999999',
      linkColor: '#4da6ff',
      borderColor: '#444444',
      dimImages: true
    };
    currentConfig = { mode: 'auto', dimImages: true, ignoreNativeDarkMode: false, siteRules: {} };
    return false;
  }

  // ============================================================
  // 激活逻辑判断
  // ============================================================

  /** 根据配置判断当前页面是否应启用深色模式 */
  function shouldActivate() {
    if (isPaused) return false;
    if (!currentConfig) return false;

    const domain = currentDomain();
    const siteMode = currentConfig.siteMode || 'follow';

    // 站点规则优先级最高
    if (siteMode === 'on') return true;
    if (siteMode === 'off') return false;

    // 跟随全局配置
    if (currentConfig.mode === 'on') return true;
    if (currentConfig.mode === 'off') return false;

    // auto 模式：跟随系统 prefers-color-scheme
    return window.matchMedia('(prefers-color-scheme: dark)').matches;
  }

  /** 提取当前页面的主域名（去掉子域名前缀） */
  function currentDomain() {
    const parts = window.location.hostname.split('.');
    return parts.length > 2 ? parts.slice(-2).join('.') : window.location.hostname;
  }

  // ============================================================
  // MutationObserver：防止动态内容产生白块
  // ============================================================

  function setupMutationObserver() {
    if (mutationObserver) {
      mutationObserver.disconnect();
    }

    mutationObserver = new MutationObserver((mutations) => {
      if (!isActive || isPaused) return;

      // 防抖：12ms 内的多次变动合并处理（平衡实时性与 CPU 占用）
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => {
        processAddedNodes(mutations);
      }, 12);
    });

    // 仅监听 childList（新增/删除节点），不监听 attribute（减少触发量）
    mutationObserver.observe(document.documentElement, {
      childList: true,
      subtree: true,
      attributes: false,
      characterData: false
    });
  }

  /** 处理新增的 DOM 节点，对亮色背景进行即时暗化 */
  function processAddedNodes(mutations) {
    if (!currentTheme) return;

    mutations.forEach(mutation => {
      mutation.addedNodes.forEach(node => {
        if (node.nodeType !== Node.ELEMENT_NODE) return;
        // 跳过 DarkReader 自己注入的节点
        if (node.id && node.id.startsWith('__dr_')) return;

        applyDarkToElement(node);

        // 对新增节点的子元素也进行处理（最多2层，避免性能问题）
        node.querySelectorAll('div, section, article, p').forEach(child => {
          applyDarkToElement(child);
        });
      });
    });
  }

  /**
   * 对单个元素进行暗化处理
   * 仅处理"亮色背景"的元素（亮度 > 50%）
   */
  function applyDarkToElement(el) {
    try {
      const computed = window.getComputedStyle(el);
      const bgColor = computed.backgroundColor;

      if (!bgColor || bgColor === 'rgba(0, 0, 0, 0)' || bgColor === 'transparent') return;

      const rgba = parseColor(bgColor);
      if (!rgba || rgba.a < 0.1) return;

      const { l } = rgbToHsl(rgba.r, rgba.g, rgba.b);
      if (l > 50) { // 只处理亮色背景
        const darkened = darkenBackground(rgba);
        if (darkened) {
          el.style.setProperty('background-color', rgbaToCSS(darkened), 'important');
        }
      }

      // 同步处理文字颜色
      const textColor = computed.color;
      const textRgba = parseColor(textColor);
      if (textRgba) {
        const { l: textL } = rgbToHsl(textRgba.r, textRgba.g, textRgba.b);
        if (textL < 30) { // 深色文字需要提亮
          const bgDarkened = darkenBackground(rgba);
          const lightened = lightenText(textRgba, bgDarkened);
          if (lightened) {
            el.style.setProperty('color', rgbaToCSS(lightened), 'important');
          }
        }
      }
    } catch (e) {
      // 忽略单元素处理错误，不影响整体
    }
  }

  // ============================================================
  // SPA 路由监听
  // ============================================================

  function setupSPADetection() {
    // Hash 路由变化（Vue Hash 模式、React Hash Router）
    window.addEventListener('hashchange', () => {
      if (isActive) reinjectAfterNavigation();
    });

    // History API 路由变化（React Router、Vue History 模式）
    if (!originalPushState) {
      originalPushState = history.pushState.bind(history);
      const origReplaceState = history.replaceState.bind(history);

      history.pushState = function (...args) {
        originalPushState(...args);
        if (isActive) reinjectAfterNavigation();
      };

      history.replaceState = function (...args) {
        origReplaceState(...args);
        if (isActive) reinjectAfterNavigation();
      };
    }

    // 浏览器前进/后退
    window.addEventListener('popstate', () => {
      if (isActive) reinjectAfterNavigation();
    });
  }

  /**
   * 路由跳转后重新注入（50ms 延迟等待 DOM 更新）
   * 双重保险：检查样式是否还在，不在则重新注入
   */
  function reinjectAfterNavigation() {
    setTimeout(() => {
      if (!document.getElementById('__dr_full__') && currentTheme) {
        injectFullStyle(currentTheme);
      }
    }, 50);
  }

  // ============================================================
  // 系统颜色模式变化监听
  // ============================================================

  function setupColorSchemeListener() {
    const darkModeQuery = window.matchMedia('(prefers-color-scheme: dark)');
    darkModeQuery.addEventListener('change', (e) => {
      if (currentConfig?.mode === 'auto') {
        if (e.matches) {
          // 系统切换到深色模式 → 激活
          if (currentTheme) injectFullStyle(currentTheme);
          setupMutationObserver();
        } else {
          // 系统切换到浅色模式 → 停用
          removeAllStyles();
          mutationObserver?.disconnect();
        }
      }
    });
  }

  // ============================================================
  // 消息监听（接收来自 popup.js 的实时指令）
  // ============================================================

  browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
    switch (message.action) {

      case 'applyTheme':
        // popup 切换主题
        currentTheme = message.theme;
        if (isActive) injectFullStyle(currentTheme);
        sendResponse({ ok: true });
        break;

      case 'setMode':
        // popup 修改站点模式（follow/on/off）
        if (currentConfig) {
          currentConfig.siteMode = message.mode;
        }
        const shouldNowActivate = shouldActivate();
        if (shouldNowActivate && !isActive) {
          injectFullStyle(currentTheme);
          setupMutationObserver();
        } else if (!shouldNowActivate && isActive) {
          removeAllStyles();
          mutationObserver?.disconnect();
        }
        sendResponse({ ok: true });
        break;

      case 'pause':
        // 一键暂停当前网站
        isPaused = true;
        removeAllStyles();
        mutationObserver?.disconnect();
        sendResponse({ ok: true });
        break;

      case 'resume':
        // 恢复深色模式
        isPaused = false;
        if (currentTheme && shouldActivate()) {
          injectFullStyle(currentTheme);
          setupMutationObserver();
        }
        sendResponse({ ok: true });
        break;

      case 'getStatus':
        // popup 查询当前状态
        sendResponse({
          isActive,
          isPaused,
          domain: currentDomain()
        });
        break;
    }

    // 返回 true 表示异步响应
    return true;
  });

  // ============================================================
  // 主流程
  // ============================================================

  async function main() {
    try {
      // 读取配置（防闪白样式已在顶部同步注入，此时可以异步加载配置）
      await loadConfig();

      if (!shouldActivate()) {
        // 不需要深色模式：移除临时防闪白样式，恢复网页原始外观
        removeAllStyles();
        return;
      }

      // 注入完整深色样式
      injectFullStyle(currentTheme);

      // 启动 DOM 变化监听（防止 SPA/动态加载产生白块）
      setupMutationObserver();

      // 监听 SPA 路由变化
      setupSPADetection();

      // 监听系统颜色模式变化
      setupColorSchemeListener();

    } catch (e) {
      // 错误降级：保留防闪白样式，记录日志
      console.error('[DarkReader] 初始化错误:', e);

      // 通知 background 记录错误日志
      try {
        browser.runtime.sendMessage({
          action: 'logError',
          domain: currentDomain(),
          errorMsg: e.message
        });
      } catch (_) { /* 忽略 */ }
    }
  }

  // 启动！
  main();

})(); // IIFE 结束，防止污染全局作用域
