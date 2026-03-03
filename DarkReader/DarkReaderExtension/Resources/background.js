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
// ★ 缩短为 800ms：App 端写入后，popup 下次打开能立即读到最新数据
//   原来 5000ms 会导致 App 改完主题后 popup 最多要等 5 秒才刷新
const CACHE_TTL = 800;

/**
 * 获取指定域名的配置
 * @param {string} domain
 * @param {boolean} skipCache - 为 true 时强制绕过缓存（popup 初始化时使用）
 */
async function getConfigForDomain(domain, skipCache = false) {
  if (!skipCache) {
    const cached = configCache.get(domain);
    if (cached && (Date.now() - cached.cachedAt) < CACHE_TTL) {
      return { config: cached.config, theme: cached.theme };
    }
  }

  // 向 Safari 原生层请求配置
  try {
    const response = await browser.runtime.sendNativeMessage(
      'com.timmy.darkreader.extension',
      { action: 'getConfig', domain }
    );

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
    // content.js / popup.js 请求配置
    // ★ 支持 fresh:true 跳过缓存（popup 打开时传入，保证读到 App 最新设置）
    case 'getConfig': {
      const domain = message.domain || '';
      const skipCache = message.fresh === true;
      getConfigForDomain(domain, skipCache)
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
      browser.runtime.sendNativeMessage(
        'com.timmy.darkreader.extension',
        { action: 'saveRule', domain, rule }
      ).then(() => {
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

    // popup.js 保存全局配置（含 defaultThemeId 变更）
    case 'saveGlobalConfig': {
      browser.runtime.sendNativeMessage(
        'com.timmy.darkreader.extension',
        { action: 'saveGlobalConfig', config: message.config }
      ).then(() => {
        // ★ 全局配置变更后清除所有域名缓存，确保下次 getConfig 读取最新值
        invalidateCache('');
        // 如需立即更新当前页面主题，通知 content.js
        if (message.config.defaultThemeId) {
          getThemeById(message.config.defaultThemeId).then(theme => {
            if (theme) notifyActiveTab({ action: 'applyTheme', theme });
          });
        }
        sendResponse({ ok: true });
      }).catch(e => {
        sendResponse({ ok: false, error: e.message });
      });
      return true;
    }

    // content.js 报告渲染错误
    case 'logError': {
      browser.runtime.sendNativeMessage(
        'com.timmy.darkreader.extension',
        {
          action: 'logError',
          domain: message.domain,
          errorMsg: message.errorMsg,
          time: new Date().toISOString()
        }
      ).catch(() => { /* 错误日志记录失败不影响主流程 */ });
      break;
    }

    // popup.js 请求所有主题列表
    case 'getThemes': {
      browser.runtime.sendNativeMessage(
        'com.timmy.darkreader.extension',
        { action: 'getThemes' }
      ).then(result => sendResponse(result))
       .catch(() => sendResponse({ themes: [] }));
      return true;
    }

    // popup.js 提交用户反馈
    case 'submitFeedback': {
      browser.runtime.sendNativeMessage(
        'com.timmy.darkreader.extension',
        { action: 'submitFeedback', feedback: message.feedback }
      ).then(() => sendResponse({ ok: true }))
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
    const result = await browser.runtime.sendNativeMessage(
      'com.timmy.darkreader.extension',
      { action: 'getThemes' }
    );
    return result?.themes?.find(t => t.id === themeId) || null;
  } catch {
    return null;
  }
}
