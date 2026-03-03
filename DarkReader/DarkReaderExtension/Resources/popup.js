/**
 * DarkReader Popup Script
 *
 * 负责：
 *   1. 展示当前域名
 *   2. 模式切换（跟随/开启/关闭）
 *   3. 主题切换
 *   4. 当前站点暂停/恢复
 *   5. 用户反馈提交
 */

'use strict';

let currentDomain = '';
let currentMode = 'follow';
// ★ currentThemeId 现在代表全局默认主题 ID（globalConfig.defaultThemeId）
//   而不是站点级覆盖主题（siteThemeId），确保与主 App 双向同步
let currentThemeId = '';
let isPaused = false;
let allThemes = [];
let currentLanguage = 'zhHans';
const SUPPORT_EMAIL = 'baibin1989@gmail.com';

const I18N = {
  zhHans: {
    brandName: '夜览',
    hero: {
      panelAria: '夜览当前站点控制面板',
      kicker: '当前站点策略',
      subtitle: '简洁控制，即时生效'
    },
    pause: {
      title: '暂停或恢复当前站点',
      banner: '当前站点策略已暂停。',
      resume: '恢复'
    },
    labels: {
      mode: '站点模式',
      theme: '站点主题'
    },
    mode: {
      follow: '跟随',
      on: '开启',
      off: '关闭'
    },
    theme: {
      followDefault: '跟随默认',
      builtinGroup: '内置主题',
      customGroup: '自定义主题',
      theme_001: '纯黑 OLED',
      theme_002: '深灰（默认）',
      theme_003: '护眼绿',
      theme_004: '暖棕色'
    },
    actions: {
      openSettings: '打开设置',
      reportIssue: '报告问题'
    },
    feedback: {
      title: '反馈问题',
      closeAria: '关闭反馈面板',
      placeholder: '请描述问题（如排版错乱、文字不清晰）...',
      submit: '提交反馈',
      submitting: '提交中...',
      emailOpened: '已打开邮件',
      mailSubjectPrefix: '[夜览] 问题反馈',
      mailGreeting: '你好，以下是用户提交的问题反馈：',
      mailSite: '网站',
      mailTheme: '主题',
      mailTime: '时间',
      mailContent: '反馈内容',
      unknown: '未知'
    },
    domain: {
      loading: '加载中...',
      unknown: '未知域名'
    }
  },
  en: {
    brandName: 'AutoDark',
    hero: {
      panelAria: 'AutoDark current site control panel',
      kicker: 'Current Site Strategy',
      subtitle: 'Simple controls, instant effect'
    },
    pause: {
      title: 'Pause or resume current site',
      banner: 'Dark strategy is paused on this site.',
      resume: 'Resume'
    },
    labels: {
      mode: 'Site Mode',
      theme: 'Site Theme'
    },
    mode: {
      follow: 'Follow',
      on: 'On',
      off: 'Off'
    },
    theme: {
      followDefault: 'Follow Default',
      builtinGroup: 'Built-in Themes',
      customGroup: 'Custom Themes',
      theme_001: 'Pure Black OLED',
      theme_002: 'Deep Gray (Default)',
      theme_003: 'Eye-care Green',
      theme_004: 'Warm Brown'
    },
    actions: {
      openSettings: 'Open Settings',
      reportIssue: 'Report Issue'
    },
    feedback: {
      title: 'Report an Issue',
      closeAria: 'Close feedback panel',
      placeholder: 'Describe the issue (for example broken layout or blurry text)...',
      submit: 'Submit Feedback',
      submitting: 'Submitting...',
      emailOpened: 'Email Opened',
      mailSubjectPrefix: '[AutoDark] Issue Feedback',
      mailGreeting: 'Hi, here is a user issue report:',
      mailSite: 'Site',
      mailTheme: 'Theme',
      mailTime: 'Time',
      mailContent: 'Details',
      unknown: 'Unknown'
    },
    domain: {
      loading: 'Loading...',
      unknown: 'Unknown Domain'
    }
  }
};

document.addEventListener('DOMContentLoaded', async () => {
  await initialize();
  bindEvents();
});

async function initialize() {
  document.getElementById('domainLabel').textContent = t('domain.loading');

  const tabs = await browser.tabs.query({ active: true, currentWindow: true });
  const tab = tabs[0];
  if (!tab) {
    applyI18n();
    return;
  }

  currentDomain = extractDomain(tab.url || '');
  document.getElementById('domainLabel').textContent = currentDomain || t('domain.unknown');

  // ★ fresh:true 强制绕过 background.js 缓存，确保读到主 App 最新写入的数据
  const result = await browser.runtime.sendMessage({
    action: 'getConfig',
    domain: currentDomain,
    fresh: true
  });

  if (result) {
    currentMode = result.config?.siteMode || 'follow';
    // ★ 关键修复：主题用 defaultThemeId（全局默认），不用 siteThemeId（站点覆盖）
    //   这样主 App 设置的默认主题能在 popup 中正确显示
    currentThemeId = result.config?.defaultThemeId || 'theme_002';
    currentLanguage = resolveLanguage(result.config?.appLanguage);
  } else {
    currentLanguage = resolveLanguage('system');
  }

  applyI18n();

  try {
    const status = await browser.tabs.sendMessage(tab.id, { action: 'getStatus' });
    isPaused = status?.isPaused || false;
  } catch (_) {
    isPaused = false;
  }

  try {
    const themesResult = await browser.runtime.sendMessage({ action: 'getThemes' });
    allThemes = themesResult?.themes || [];
  } catch (_) {
    allThemes = defaultThemes();
  }

  renderModeControl();
  renderThemeSelect();
  renderPauseState();
}

function applyI18n() {
  document.documentElement.lang = currentLanguage === 'en' ? 'en' : 'zh-CN';
  document.title = t('brandName');

  setText('heroTitle', t('brandName'));
  setText('heroKicker', t('hero.kicker'));
  setText('heroSubtitle', t('hero.subtitle'));
  setText('pauseBannerText', t('pause.banner'));
  setText('resumeBtn', t('pause.resume'));
  setText('modeLabel', t('labels.mode'));
  setText('themeLabel', t('labels.theme'));
  setText('openAppBtnText', t('actions.openSettings'));
  setText('reportBtnText', t('actions.reportIssue'));
  setText('feedbackTitle', t('feedback.title'));

  const pauseBtn = document.getElementById('pauseBtn');
  if (pauseBtn) {
    pauseBtn.title = t('pause.title');
    pauseBtn.setAttribute('aria-label', t('pause.title'));
  }

  const heroCard = document.getElementById('heroCard');
  if (heroCard) {
    heroCard.setAttribute('aria-label', t('hero.panelAria'));
  }

  const closeFeedback = document.getElementById('closeFeedback');
  if (closeFeedback) {
    closeFeedback.setAttribute('aria-label', t('feedback.closeAria'));
  }

  const feedbackText = document.getElementById('feedbackText');
  if (feedbackText) {
    feedbackText.placeholder = t('feedback.placeholder');
  }

  const submitFeedback = document.getElementById('submitFeedback');
  if (submitFeedback && !submitFeedback.disabled) {
    submitFeedback.textContent = t('feedback.submit');
  }

  document.querySelectorAll('#modeControl .seg-btn').forEach(btn => {
    const modeKey = btn.dataset.value;
    if (!modeKey) return;
    const label = t(`mode.${modeKey}`);
    if (label) btn.textContent = label;
  });

  if (!currentDomain) {
    setText('domainLabel', t('domain.unknown'));
  }
}

function renderModeControl() {
  const buttons = document.querySelectorAll('#modeControl .seg-btn');
  buttons.forEach(btn => {
    btn.classList.toggle('active', btn.dataset.value === currentMode);
  });
}

function renderThemeSelect() {
  const select = document.getElementById('themeSelect');
  // ★ 移除"跟随默认"选项：popup 现在直接控制全局默认主题，没有"跟随"概念
  //   每次打开 popup 显示的即是当前实际生效的全局主题
  select.innerHTML = '';

  const builtins = allThemes.filter(th => th.isBuiltin);
  if (builtins.length > 0) {
    const group = document.createElement('optgroup');
    group.label = t('theme.builtinGroup');
    builtins.forEach(theme => {
      const opt = document.createElement('option');
      opt.value = theme.id;
      opt.textContent = localizedThemeName(theme);
      opt.selected = theme.id === currentThemeId;
      group.appendChild(opt);
    });
    select.appendChild(group);
  }

  const customs = allThemes.filter(th => !th.isBuiltin);
  if (customs.length > 0) {
    const group = document.createElement('optgroup');
    group.label = t('theme.customGroup');
    customs.forEach(theme => {
      const opt = document.createElement('option');
      opt.value = theme.id;
      opt.textContent = theme.name;
      opt.selected = theme.id === currentThemeId;
      group.appendChild(opt);
    });
    select.appendChild(group);
  }

  select.value = currentThemeId;
}

function renderPauseState() {
  const pauseBtn = document.getElementById('pauseBtn');
  const pauseBanner = document.getElementById('pauseBanner');

  pauseBtn.classList.toggle('paused', isPaused);
  pauseBtn.setAttribute('aria-pressed', String(isPaused));
  pauseBanner.classList.toggle('hidden', !isPaused);
}

function bindEvents() {
  document.querySelectorAll('#modeControl .seg-btn').forEach(btn => {
    btn.addEventListener('click', async () => {
      currentMode = btn.dataset.value;
      renderModeControl();
      await saveRuleAndNotify();
    });
  });

  document.getElementById('themeSelect').addEventListener('change', async e => {
    const newThemeId = e.target.value;
    if (!newThemeId) return;

    currentThemeId = newThemeId;

    // ① 最优先：立即通知当前网页应用新主题
    //    必须在任何 await 之前发出，保证无论 save 成功与否，视觉响应都即时生效
    const theme = allThemes.find(th => th.id === newThemeId);
    if (theme) {
      notifyActiveTab({ action: 'applyTheme', theme });
    }

    // ② 异步保存全局默认主题到 App Groups（不 await，错误不影响 UI）
    //    主 App 的 1.2s 定时器检测到 globalConfig 变化后，会自动更新界面
    browser.runtime.sendMessage({
      action: 'saveGlobalConfig',
      config: { defaultThemeId: newThemeId }
    }).catch(e => console.warn('[DarkReader] saveGlobalConfig 失败:', e));

    // ③ 清除当前站点的主题覆盖（不 await，避免阻塞）
    if (currentDomain) {
      browser.runtime.sendMessage({
        action: 'saveRule',
        domain: currentDomain,
        rule: { mode: currentMode, themeId: '' }
      }).catch(() => {});
    }
  });

  document.getElementById('pauseBtn').addEventListener('click', async () => {
    isPaused = !isPaused;
    renderPauseState();
    notifyActiveTab({ action: isPaused ? 'pause' : 'resume' });
  });

  document.getElementById('resumeBtn').addEventListener('click', () => {
    isPaused = false;
    renderPauseState();
    notifyActiveTab({ action: 'resume' });
  });

  document.getElementById('openAppBtn').addEventListener('click', async () => {
    // ★ 唤起主 App 的标准方式：让当前标签页导航到自定义 URL Scheme。
    //   Safari 拦截到 darkreader:// 后，会弹出系统对话框
    //   "Safari 要打开 AutoDark" → 用户点"打开" → 主 App 启动并跳转到设置页。
    //
    //   注意：不能用 window.location.href（popup 内部跳转无效）；
    //         不能用 sendNativeMessage（iOS Safari 扩展进程无法直接调用 UIApplication.open）；
    //         必须通过 tabs.update 让真实标签页发起跳转，才能触发系统对话框。
    try {
      const tabs = await browser.tabs.query({ active: true, currentWindow: true });
      if (tabs[0]?.id) {
        // 在当前标签页跳转到 URL Scheme，Safari 会弹"打开 App"对话框
        await browser.tabs.update(tabs[0].id, { url: 'darkreader://settings' });
      } else {
        // 无活跃标签页时，新建一个标签页来触发跳转
        await browser.tabs.create({ url: 'darkreader://settings' });
      }
    } catch (_) {
      // 极端情况降级：直接在 popup 内跳转（部分版本 Safari 也能触发 App 对话框）
      try {
        await browser.tabs.create({ url: 'darkreader://settings' });
      } catch (_2) { /* 静默忽略 */ }
    }
    // 跳转已发起，关闭 popup
    window.close();
  });

  document.getElementById('reportBtn').addEventListener('click', () => {
    document.getElementById('feedbackPanel').classList.toggle('hidden');
  });

  document.getElementById('closeFeedback').addEventListener('click', () => {
    document.getElementById('feedbackPanel').classList.add('hidden');
    document.getElementById('feedbackText').value = '';
  });

  document.getElementById('submitFeedback').addEventListener('click', async () => {
    const text = document.getElementById('feedbackText').value.trim();
    if (!text) return;

    const submitBtn = document.getElementById('submitFeedback');
    submitBtn.disabled = true;
    submitBtn.textContent = t('feedback.submitting');

    const feedback = {
      domain: currentDomain,
      themeId: currentThemeId,
      content: text,
      time: new Date().toISOString()
    };

    // 本地保留一份反馈记录，不阻塞后续邮件动作
    try {
      await browser.runtime.sendMessage({
        action: 'submitFeedback',
        feedback
      });
    } catch (_) {}

    await openFeedbackEmail(feedback);
    submitBtn.textContent = t('feedback.emailOpened');
    setTimeout(() => {
      document.getElementById('feedbackPanel').classList.add('hidden');
      document.getElementById('feedbackText').value = '';
      submitBtn.disabled = false;
      submitBtn.textContent = t('feedback.submit');
    }, 1200);
  });
}

// ★ 仅保存当前站点的 Mode 规则（开启/关闭/跟随）
//   主题同步已独立处理（直接写 globalConfig.defaultThemeId），不在此混入
async function saveRuleAndNotify() {
  const rule = {
    mode: currentMode,
    themeId: '' // 主题覆盖由主题选择器单独处理，此处不传递
  };

  await browser.runtime.sendMessage({
    action: 'saveRule',
    domain: currentDomain,
    rule
  });

  notifyActiveTab({ action: 'setMode', mode: currentMode });
}

async function notifyActiveTab(message) {
  const tabs = await browser.tabs.query({ active: true, currentWindow: true });
  if (tabs[0]) {
    browser.tabs.sendMessage(tabs[0].id, message).catch(() => {});
  }
}

function extractDomain(url) {
  try {
    const hostname = new URL(url).hostname;
    const parts = hostname.split('.');
    return parts.length > 2 ? parts.slice(-2).join('.') : hostname;
  } catch {
    return '';
  }
}

function defaultThemes() {
  return [
    { id: 'theme_001', name: 'theme_001', isBuiltin: true },
    { id: 'theme_002', name: 'theme_002', isBuiltin: true },
    { id: 'theme_003', name: 'theme_003', isBuiltin: true },
    { id: 'theme_004', name: 'theme_004', isBuiltin: true }
  ];
}

function localizedThemeName(theme) {
  if (!theme?.isBuiltin) return theme?.name || '';

  const key = `theme.${theme.id}`;
  const localized = t(key);
  return localized || theme.name || theme.id;
}

function buildFeedbackMailtoUrl(feedback) {
  const subjectDomain = feedback.domain || 'unknown-domain';
  const subject = `${t('feedback.mailSubjectPrefix')} - ${subjectDomain}`;

  const body = [
    t('feedback.mailGreeting'),
    '',
    `${t('feedback.mailSite')}: ${feedback.domain || t('feedback.unknown')}`,
    `${t('feedback.mailTheme')}: ${feedback.themeId || t('theme.followDefault')}`,
    `${t('feedback.mailTime')}: ${feedback.time || new Date().toISOString()}`,
    '',
    `${t('feedback.mailContent')}:`,
    feedback.content || ''
  ].join('\n');

  return `mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
}

async function openFeedbackEmail(feedback) {
  const url = buildFeedbackMailtoUrl(feedback);
  try {
    await browser.tabs.create({ url });
  } catch (_) {
    window.location.href = url;
  }
}

function resolveLanguage(option) {
  if (option === 'en') return 'en';
  if (option === 'zhHans') return 'zhHans';

  const locale = (navigator.language || '').toLowerCase();
  if (locale.startsWith('zh')) return 'zhHans';
  return 'en';
}

function t(key) {
  const table = I18N[currentLanguage] || I18N.zhHans;
  return key.split('.').reduce((acc, part) => {
    if (acc && typeof acc === 'object' && part in acc) {
      return acc[part];
    }
    return '';
  }, table);
}

function setText(id, value) {
  const node = document.getElementById(id);
  if (node) node.textContent = value;
}

function escapeHTML(text) {
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
