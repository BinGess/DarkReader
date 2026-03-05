const test = require('node:test');
const assert = require('node:assert/strict');

const {
  normalizeThreshold,
  evaluateLowBatteryActivation,
  evaluateLowBatteryRuntimeState
} = require('../lowBatteryPolicy.js');

test('normalizeThreshold only accepts 10/20/30 and falls back to 20', () => {
  assert.equal(normalizeThreshold(10), 10);
  assert.equal(normalizeThreshold(20), 20);
  assert.equal(normalizeThreshold(30), 30);
  assert.equal(normalizeThreshold(25), 20);
  assert.equal(normalizeThreshold(undefined), 20);
});

test('evaluateLowBatteryActivation prefers navigator battery data when available', () => {
  const result = evaluateLowBatteryActivation({
    config: {
      lowBatteryEyeCareEnabled: true,
      lowBatteryThreshold: 20,
      lowBatteryModeActive: false
    },
    batterySnapshot: {
      supported: true,
      available: true,
      level: 0.15,
      charging: false
    }
  });

  assert.equal(result.shouldForceDark, true);
  assert.equal(result.source, 'navigator');
  assert.equal(result.isLowBattery, true);
});

test('evaluateLowBatteryActivation falls back to appGroup flag when battery API unavailable', () => {
  const result = evaluateLowBatteryActivation({
    config: {
      lowBatteryEyeCareEnabled: true,
      lowBatteryThreshold: 20,
      lowBatteryModeActive: true
    },
    batterySnapshot: {
      supported: false,
      available: false
    }
  });

  assert.equal(result.shouldForceDark, true);
  assert.equal(result.source, 'app_group');
  assert.equal(result.isLowBattery, true);
});

test('evaluateLowBatteryRuntimeState applies 3% hysteresis on recovery', () => {
  const activated = evaluateLowBatteryRuntimeState({
    currentlyForced: false,
    threshold: 20,
    batterySnapshot: {
      supported: true,
      available: true,
      level: 0.19,
      charging: false
    },
    restoreOnCharging: true,
    fallbackActive: false
  });
  assert.equal(activated.shouldForceDark, true);

  const keepForced = evaluateLowBatteryRuntimeState({
    currentlyForced: true,
    threshold: 20,
    batterySnapshot: {
      supported: true,
      available: true,
      level: 0.22,
      charging: false
    },
    restoreOnCharging: true,
    fallbackActive: false
  });
  assert.equal(keepForced.shouldForceDark, true);

  const recover = evaluateLowBatteryRuntimeState({
    currentlyForced: true,
    threshold: 20,
    batterySnapshot: {
      supported: true,
      available: true,
      level: 0.24,
      charging: false
    },
    restoreOnCharging: true,
    fallbackActive: false
  });
  assert.equal(recover.shouldForceDark, false);
});

test('evaluateLowBatteryRuntimeState can keep forced mode when restoreOnCharging is false', () => {
  const result = evaluateLowBatteryRuntimeState({
    currentlyForced: true,
    threshold: 20,
    batterySnapshot: {
      supported: true,
      available: true,
      level: 0.8,
      charging: true
    },
    restoreOnCharging: false,
    fallbackActive: true
  });

  assert.equal(result.shouldForceDark, true);
  assert.equal(result.source, 'navigator');
});
