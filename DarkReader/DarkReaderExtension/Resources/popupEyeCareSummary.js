(function initPopupEyeCareSummary(root) {
  'use strict';

  function normalizeNonNegativeNumber(value) {
    const parsed = typeof value === 'number' ? value : Number(value);
    if (!Number.isFinite(parsed) || parsed <= 0) {
      return 0;
    }
    return parsed;
  }

  function normalizeShieldPoints(value) {
    return Math.max(Math.trunc(normalizeNonNegativeNumber(value)), 0);
  }

  function formatDuration(seconds) {
    const safeSeconds = normalizeNonNegativeNumber(seconds);
    if (safeSeconds <= 0) return '0m';

    const totalMinutes = Math.floor(safeSeconds / 60);
    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;
    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    }
    return `${Math.max(totalMinutes, 0)}m`;
  }

  function buildEyeCareSummaryDisplay(input) {
    const payload = input || {};
    const isActiveOnPage = payload.isActiveOnPage === true;
    const isPaused = payload.isPaused === true;
    const shouldApplyMinimum = isActiveOnPage && !isPaused;

    const rawDurationSeconds = normalizeNonNegativeNumber(payload.durationSeconds);
    const rawShieldPoints = normalizeShieldPoints(payload.darkShieldPoints);

    const durationSeconds = shouldApplyMinimum
      ? Math.max(rawDurationSeconds, 60)
      : rawDurationSeconds;
    const shieldPoints = shouldApplyMinimum
      ? Math.max(rawShieldPoints, 1)
      : rawShieldPoints;

    const suffix = typeof payload.reductionSuffix === 'string'
      ? payload.reductionSuffix.trim()
      : '';
    const reductionText = suffix.length > 0
      ? `${shieldPoints} ${suffix}`
      : String(shieldPoints);

    return {
      shouldApplyMinimum,
      durationSeconds,
      shieldPoints,
      durationText: formatDuration(durationSeconds),
      reductionText
    };
  }

  const api = {
    normalizeNonNegativeNumber,
    normalizeShieldPoints,
    formatDuration,
    buildEyeCareSummaryDisplay
  };

  root.DarkReaderPopupEyeCareSummary = api;
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
