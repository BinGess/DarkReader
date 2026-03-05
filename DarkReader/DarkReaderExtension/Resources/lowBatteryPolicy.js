(function initLowBatteryPolicy(root) {
  'use strict';

  function normalizeThreshold(value) {
    return [10, 20, 30].includes(value) ? value : 20;
  }

  function normalizeBatterySnapshot(snapshot) {
    const source = snapshot || {};
    const supported = source.supported !== false;
    const level = typeof source.level === 'number' ? source.level : NaN;
    const charging = typeof source.charging === 'boolean' ? source.charging : false;
    const levelValid = Number.isFinite(level) && level >= 0 && level <= 1;

    return {
      supported,
      available: !!supported && levelValid,
      level: levelValid ? level : NaN,
      charging
    };
  }

  function evaluateLowBatteryRuntimeState(params) {
    const input = params || {};
    const threshold = normalizeThreshold(input.threshold);
    const battery = normalizeBatterySnapshot(input.batterySnapshot);
    const currentlyForced = !!input.currentlyForced;
    const restoreOnCharging = input.restoreOnCharging !== false;
    const fallbackActive = !!input.fallbackActive;

    if (!battery.available) {
      return {
        shouldForceDark: fallbackActive,
        isLowBattery: fallbackActive,
        source: 'app_group',
        threshold,
        recoveryThreshold: Math.min(threshold + 3, 100),
        batteryLevel: null,
        charging: false
      };
    }

    const thresholdRatio = threshold / 100;
    const recoveryThreshold = Math.min(threshold + 3, 100);
    const recoveryRatio = recoveryThreshold / 100;
    const shouldActivate = battery.level <= thresholdRatio && battery.charging !== true;

    let shouldForceDark;
    if (currentlyForced) {
      if (shouldActivate) {
        shouldForceDark = true;
      } else if (!restoreOnCharging) {
        shouldForceDark = true;
      } else {
        const shouldRecover = battery.charging === true || battery.level > recoveryRatio;
        shouldForceDark = !shouldRecover;
      }
    } else {
      shouldForceDark = shouldActivate;
    }

    return {
      shouldForceDark,
      isLowBattery: shouldActivate,
      source: 'navigator',
      threshold,
      recoveryThreshold,
      batteryLevel: battery.level,
      charging: battery.charging
    };
  }

  function evaluateLowBatteryActivation(params) {
    const input = params || {};
    const config = input.config || {};

    if (!config.lowBatteryEyeCareEnabled) {
      return {
        shouldForceDark: false,
        isLowBattery: false,
        source: 'disabled',
        threshold: normalizeThreshold(config.lowBatteryThreshold),
        recoveryThreshold: Math.min(normalizeThreshold(config.lowBatteryThreshold) + 3, 100),
        batteryLevel: null,
        charging: false
      };
    }

    return evaluateLowBatteryRuntimeState({
      currentlyForced: !!input.currentlyForced,
      threshold: config.lowBatteryThreshold,
      batterySnapshot: input.batterySnapshot,
      restoreOnCharging: config.lowBatteryRestoreOnCharging !== false,
      fallbackActive: !!config.lowBatteryModeActive
    });
  }

  const api = {
    normalizeThreshold,
    evaluateLowBatteryRuntimeState,
    evaluateLowBatteryActivation
  };

  root.DarkReaderLowBatteryPolicy = api;
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
