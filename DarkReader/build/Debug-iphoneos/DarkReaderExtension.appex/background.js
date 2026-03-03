/**
 * DarkReader Background Script（Service Worker）
 *
 * 职责：
 *   1. 作为 content.js 与 Safari 原生层（SafariWebExtensionHandler）的消息中转
 *   2. 缓存配置，减少与 native 的通信次数（降低延迟）
 *   3. 处理错误日志写入
 *
 * 通信链路：
 *   content.js → background.js → SafariWebExtensionHandler.swift → App Groups UserDefaults
 *
 * 注意：Safari Manifest V3 中 background 为 Service Worker，
 *       不保证持续运行，重要状态需外部持久化。
 */

'use strict';

// ============================================================
// 配置缓存（减少 native 调用次数）
// ============================================================

// 缓存结构：{ [domain]: { config, theme, cachedAt } }
const configCache = new Map();
const CACHE_TTL = 5000; // 5秒缓存有效期
const NATIVE_APP_ID = 'com.timmy.darkreader.extension';
const MAX_NATIVE_RETRIES = 2;
const NATIVE_RETRY_DELAY_MS = 80;

/**
 * Native 通信统一入口（带重试）
 * Safari 扩展进程偶发不可用时，短退避重试可显著降低失败率。
 */
async function sendNativeWithRetry(payload, retries = MAX_NATIVE_RETRIES) {
  let lastError = null;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      return await browser.runtime.sendNativeMessage(NATIVE_APP_ID, payload);
    } catch (e) {
      lastError = e;
      if (attempt === retries) break;
      await new Promise(resolve => setTimeout(resolve, NATIVE_RETRY_DELAY_MS * (attempt + 1)));
    }
  }
  throw lastError || new Error('Native communication failed');
}

/**
 * 获取指定域名的配置
 * 优先从缓存读取，超时或未缓存则请求 native
 */
async function getConfigForDomain(domain) {
  const cached = configCache.get(domain);
  if (cached && (Date.now() - cached.cachedAt) < CACHE_TTL) {
    return { config: cached.config, theme: cached.theme };
  }

  // 向 Safari 原生层请求配置
  try {
    const response = await sendNativeWithRetry({ action: 'getConfig', domain });

    if (response && response.theme) {
      // 存入缓存
      configCache.set(domain, {
        config: response.config,
        theme: response.theme,
        cachedAt: Date.now()
      });
      return response;
    }
  } catch (e) {
    console.warn('[DarkReader BG] Native 通信失败:', e.message);
  }

  // 通信失败降级：返回硬编码默认值
  return {
    config: {
      mode: 'auto',
      dimImages: true,
      ignoreNativeDarkMode: false,
      performanceMode: false,
      siteMode: 'follow',
      siteThemeId: ''
    },
    theme: {
      backgroundColor: '#1e1e1e',
      textColor: '#e0e0e0',
      secondaryTextColor: '#999999',
      linkColor: '#4da6ff',
      borderColor: '#444444',
      dimImages: true
    }
  };
}

/**
 * 使指定域名的缓存失效（保存规则后调用）
 */
function invalidateCache(domain) {
  configCache.delete(domain);
  // 也清除通配符缓存（全局配置可能影响所有域名）
  configCache.clear();
}

// ============================================================
// 消息处理中枢
// ============================================================

browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
  const { action } = message;

  switch (action) {
    // content.js 请求配置
    case 'getConfig': {
      const domain = message.domain || '';
      getConfigForDomain(domain)
        .then(result => sendResponse(result))
        .catch(e => {
          console.error('[DarkReader BG] getConfig 失败:', e);
          sendResponse(null);
        });
      return true; // 异步响应
    }

    // popup.js 保存站点规则
    case 'saveRule': {
      const { domain, rule } = message;
      sendNativeWithRetry({ action: 'saveRule', domain, rule }).then(() => {
        invalidateCache(domain);
        // 通知当前标签页的 content.js 刷新
        notifyActiveTab({ action: 'setMode', mode: rule.mode || 'follow' });
        if (rule.themeId) {
          getThemeById(rule.themeId).then(theme => {
            if (theme) notifyActiveTab({ action: 'applyTheme', theme });
          });
        }
        sendResponse({ ok: true });
      }).catch(e => {
        console.error('[DarkReader BG] saveRule 失败:', e);
        sendResponse({ ok: false, error: e.message });
      });
      return true;
    }

    // popup.js 保存全局配置
    case 'saveGlobalConfig': {
      sendNativeWithRetry({ action: 'saveGlobalConfig', config: message.config }).then(() => {
        invalidateCache(''); // 清除所有缓存
        sendResponse({ ok: true });
      }).catch(e => {
        sendResponse({ ok: false, error: e.message });
      });
      return true;
    }

    // content.js 报告渲染错误
    case 'logError': {
      sendNativeWithRetry({
        action: 'logError',
        domain: message.domain,
        errorMsg: message.errorMsg,
        time: new Date().toISOString()
      }).catch(() => { /* 错误日志记录失败不影响主流程 */ });
      break;
    }

    // popup.js 请求所有主题列表
    case 'getThemes': {
      sendNativeWithRetry({ action: 'getThemes' }).then(result => sendResponse(result))
       .catch(() => sendResponse({ themes: [] }));
      return true;
    }

    // popup.js 提交用户反馈
    case 'submitFeedback': {
      sendNativeWithRetry({ action: 'submitFeedback', feedback: message.feedback }).then(() => sendResponse({ ok: true }))
       .catch(() => sendResponse({ ok: false }));
      return true;
    }
  }
});

// ============================================================
// 工具函数
// ============================================================

/** 向当前活跃标签页的 content.js 发送消息 */
async function notifyActiveTab(message) {
  try {
    const tabs = await browser.tabs.query({ active: true, currentWindow: true });
    if (tabs[0]) {
      await browser.tabs.sendMessage(tabs[0].id, message);
    }
  } catch (e) {
    // 标签页可能已关闭，忽略
  }
}

/** 根据主题 ID 获取主题配置 */
async function getThemeById(themeId) {
  try {
    const result = await sendNativeWithRetry({ action: 'getThemes' });
    return result?.themes?.find(t => t.id === themeId) || null;
  } catch {
    return null;
  }
}
