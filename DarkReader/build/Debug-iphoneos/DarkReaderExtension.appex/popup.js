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
let currentThemeId = '';
let isPaused = false;
let allThemes = [];

document.addEventListener('DOMContentLoaded', async () => {
  await initialize();
  bindEvents();
});

async function initialize() {
  const tabs = await browser.tabs.query({ active: true, currentWindow: true });
  const tab = tabs[0];
  if (!tab) return;

  currentDomain = extractDomain(tab.url || '');
  document.getElementById('domainLabel').textContent = currentDomain || '未知域名';

  const result = await browser.runtime.sendMessage({
    action: 'getConfig',
    domain: currentDomain
  });

  if (result) {
    currentMode = result.config?.siteMode || 'follow';
    currentThemeId = result.config?.siteThemeId || '';
  }

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

function renderModeControl() {
  const buttons = document.querySelectorAll('#modeControl .seg-btn');
  buttons.forEach(btn => {
    btn.classList.toggle('active', btn.dataset.value === currentMode);
  });
}

function renderThemeSelect() {
  const select = document.getElementById('themeSelect');
  select.innerHTML = '<option value="">跟随默认</option>';

  const builtins = allThemes.filter(t => t.isBuiltin);
  if (builtins.length > 0) {
    const group = document.createElement('optgroup');
    group.label = '内置主题';
    builtins.forEach(theme => {
      const opt = document.createElement('option');
      opt.value = theme.id;
      opt.textContent = theme.name;
      opt.selected = theme.id === currentThemeId;
      group.appendChild(opt);
    });
    select.appendChild(group);
  }

  const customs = allThemes.filter(t => !t.isBuiltin);
  if (customs.length > 0) {
    const group = document.createElement('optgroup');
    group.label = '自定义主题';
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
    currentThemeId = e.target.value;
    await saveRuleAndNotify();

    if (currentThemeId) {
      const theme = allThemes.find(t => t.id === currentThemeId);
      if (theme) {
        notifyActiveTab({ action: 'applyTheme', theme });
      }
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

  document.getElementById('openAppBtn').addEventListener('click', () => {
    browser.runtime.sendNativeMessage(
      'com.timmy.darkreader.extension',
      { action: 'openApp' }
    ).catch(() => {});
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
    submitBtn.textContent = '提交中...';

    await browser.runtime.sendMessage({
      action: 'submitFeedback',
      feedback: {
        domain: currentDomain,
        themeId: currentThemeId,
        content: text,
        time: new Date().toISOString()
      }
    });

    submitBtn.textContent = '提交成功';
    setTimeout(() => {
      document.getElementById('feedbackPanel').classList.add('hidden');
      document.getElementById('feedbackText').value = '';
      submitBtn.disabled = false;
      submitBtn.textContent = '提交反馈';
    }, 1200);
  });
}

async function saveRuleAndNotify() {
  const rule = {
    mode: currentMode,
    themeId: currentThemeId
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
    { id: 'theme_001', name: '纯黑 OLED', isBuiltin: true },
    { id: 'theme_002', name: '深灰（默认）', isBuiltin: true },
    { id: 'theme_003', name: '护眼绿', isBuiltin: true },
    { id: 'theme_004', name: '暖棕色', isBuiltin: true }
  ];
}
