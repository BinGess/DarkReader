const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildEyeCareSummaryDisplay
} = require('../popupEyeCareSummary.js');

test('active and not paused applies minimum fallback for invalid or zero stats', () => {
  const result = buildEyeCareSummaryDisplay({
    durationSeconds: '-',
    darkShieldPoints: 0,
    isActiveOnPage: true,
    isPaused: false,
    reductionSuffix: '点'
  });

  assert.equal(result.durationText, '1m');
  assert.equal(result.reductionText, '1 点');
});

test('inactive page keeps zero stats without minimum fallback', () => {
  const result = buildEyeCareSummaryDisplay({
    durationSeconds: 0,
    darkShieldPoints: 0,
    isActiveOnPage: false,
    isPaused: false,
    reductionSuffix: '点'
  });

  assert.equal(result.durationText, '0m');
  assert.equal(result.reductionText, '0 点');
});

test('paused state keeps zero stats without minimum fallback', () => {
  const result = buildEyeCareSummaryDisplay({
    durationSeconds: 0,
    darkShieldPoints: 0,
    isActiveOnPage: true,
    isPaused: true,
    reductionSuffix: '点'
  });

  assert.equal(result.durationText, '0m');
  assert.equal(result.reductionText, '0 点');
});

test('active state preserves actual values above minimum threshold', () => {
  const result = buildEyeCareSummaryDisplay({
    durationSeconds: 3720,
    darkShieldPoints: 8.9,
    isActiveOnPage: true,
    isPaused: false,
    reductionSuffix: '点'
  });

  assert.equal(result.durationText, '1h 2m');
  assert.equal(result.reductionText, '8 点');
});

