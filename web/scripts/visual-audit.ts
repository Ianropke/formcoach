import { chromium, devices } from 'playwright';
import * as fs from 'fs';
import * as path from 'path';

const SCREENSHOT_DIR = '/Users/ianropke/.gemini/antigravity/brain/1154251b-b0c0-44cb-b318-a32359591946/screenshots';

if (!fs.existsSync(SCREENSHOT_DIR)) {
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
}

async function runVisualAudit() {
  console.log('🚀 Starting Comprehensive FormCoach Visual Audit...');
  const browser = await chromium.launch({
    headless: true,
    args: ['--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream']
  });

  // 1. Mobile Safari Viewport (iPhone 14 Pro)
  const mobileContext = await browser.newContext({
    ...devices['iPhone 14 Pro'],
    permissions: ['camera']
  });
  const mobilePage = await mobileContext.newPage();

  mobilePage.on('pageerror', err => console.error('[PAGEERROR][Mobile]', err));
  mobilePage.on('console', msg => {
    if (msg.type() === 'error') console.error('[CONSOLE][Mobile]', msg.text());
  });

  await mobilePage.goto('http://localhost:3000', { waitUntil: 'networkidle' });
  console.log('✓ Loaded mobile routine');

  // Screenshot 1: Mobile Routine
  await mobilePage.screenshot({ path: path.join(SCREENSHOT_DIR, 'formcoach-01-mobile-routine.png') });

  // Screenshot 2: Baselines
  await mobilePage.locator('button:has-text("Baselines")').click();
  await mobilePage.waitForTimeout(400);
  await mobilePage.screenshot({ path: path.join(SCREENSHOT_DIR, 'formcoach-02-mobile-baselines.png') });

  // Return to routine
  await mobilePage.locator('button:has-text("Routine")').click();
  await mobilePage.waitForTimeout(300);

  // Click on Squat card and launch camera setup
  await mobilePage.locator('div:has-text("Squat")').first().click();
  await mobilePage.waitForTimeout(200);

  // Click the main action button
  await mobilePage.locator('button:has-text("Setup")').first().click();
  await mobilePage.waitForTimeout(800);

  // Screenshot 3: Camera Setup View with Quality Gate & Flip Button
  await mobilePage.screenshot({ path: path.join(SCREENSHOT_DIR, 'formcoach-03-mobile-camera-setup.png') });

  // Toggle Telemetry HUD
  const telemBtn = mobilePage.locator('button[title="Toggle Performance Telemetry"]');
  if (await telemBtn.isVisible()) {
    await telemBtn.click();
    await mobilePage.waitForTimeout(400);
    await mobilePage.screenshot({ path: path.join(SCREENSHOT_DIR, 'formcoach-03b-mobile-telemetry-hud.png') });
    await telemBtn.click();
  }

  // Flip Camera
  const flipBtn = mobilePage.locator('button[title="Flip Camera (Front/Rear)"]');
  if (await flipBtn.isVisible()) {
    await flipBtn.click();
    await mobilePage.waitForTimeout(400);
    await mobilePage.screenshot({ path: path.join(SCREENSHOT_DIR, 'formcoach-04-mobile-camera-flipped.png') });
  }

  // Go back to selector
  await mobilePage.locator('button').first().click();
  await mobilePage.waitForTimeout(300);

  // Mock Set 1: Squat Set
  const squatSet = {
    id: 'set_squat_1',
    exercise: 'squat',
    view: 'side',
    date: new Date().toISOString(),
    reps: [
      { index: 1, startTime: 0, inflectionTime: 1.2, endTime: 2.2, duration: 2.2, concentricDuration: 1.0, eccentricDuration: 1.2, primaryROM: 82, confidence: 0.98 },
      { index: 2, startTime: 2.5, inflectionTime: 3.7, endTime: 4.8, duration: 2.3, concentricDuration: 1.1, eccentricDuration: 1.2, primaryROM: 84, confidence: 0.98 },
      { index: 3, startTime: 5.1, inflectionTime: 6.3, endTime: 7.5, duration: 2.4, concentricDuration: 1.2, eccentricDuration: 1.2, primaryROM: 85, confidence: 0.97 },
      { index: 4, startTime: 7.8, inflectionTime: 9.1, endTime: 10.3, duration: 2.5, concentricDuration: 1.2, eccentricDuration: 1.3, primaryROM: 88, confidence: 0.96 }
    ],
    analysis: {
      overallScore: 95,
      romScore: 98,
      consistencyScore: 94,
      tempoScore: 92,
      primaryObservation: 'Consistently achieved full ~84° (±2.5°) depth across all 4 reps with strict parallel kinematics.',
      observations: [
        {
          id: 'squat.depth.parallel',
          title: 'Deep & Parallel Squats',
          detail: 'Consistently achieved full ~84° (±2.5°) depth across all 4 reps.',
          evidence: 'Full range of motion verified mathematically.',
          severity: 'positive',
          affectedReps: [1, 2, 3, 4]
        }
      ],
      repCount: 4,
      meanROM: 84.75,
      romStdDev: 2.5,
      meanDuration: 2.35,
      tempoStdDev: 0.13,
      concentricMean: 1.1,
      eccentricMean: 1.2,
      stabilityStatus: 'STRICT_STABILITY'
    }
  };

  // Screenshot 5: Squat Results View with Dynamic Mathematical Skeleton
  await mobilePage.evaluate((set) => {
    window.dispatchEvent(new CustomEvent('formcoach_test_flow', {
      detail: { flow: 'results', set }
    }));
  }, squatSet);
  await mobilePage.waitForTimeout(600);
  await mobilePage.screenshot({ path: path.join(SCREENSHOT_DIR, 'formcoach-05-mobile-results-squat.png') });

  // Screenshot 6: Bicep Curls Results View with Relative Drift
  const curlSet = {
    id: 'set_curl_1',
    exercise: 'bicepsCurl',
    view: 'side',
    date: new Date().toISOString(),
    reps: [
      { index: 1, startTime: 0, inflectionTime: 1.0, endTime: 2.0, duration: 2.0, concentricDuration: 1.0, eccentricDuration: 1.0, primaryROM: 50, secondaryROM: 5.2, confidence: 0.98 },
      { index: 2, startTime: 2.2, inflectionTime: 3.2, endTime: 4.2, duration: 2.0, concentricDuration: 1.0, eccentricDuration: 1.0, primaryROM: 52, secondaryROM: 4.8, confidence: 0.98 },
      { index: 3, startTime: 4.5, inflectionTime: 5.5, endTime: 6.6, duration: 2.1, concentricDuration: 1.0, eccentricDuration: 1.1, primaryROM: 54, secondaryROM: 6.1, confidence: 0.97 }
    ],
    analysis: {
      overallScore: 94,
      romScore: 95,
      consistencyScore: 92,
      tempoScore: 90,
      primaryObservation: 'Strict biceps isolation with pinned elbows under Δ6.1° relative shoulder drift.',
      observations: [
        {
          id: 'curl.form.strict',
          title: 'Strict Bicep Isolation',
          detail: 'Elbows stayed tightly pinned with under Δ6.1° relative shoulder drift.',
          evidence: 'Strict curl execution verified relative to setup anchor.',
          severity: 'positive',
          affectedReps: [1, 2, 3]
        }
      ],
      repCount: 3,
      meanROM: 52,
      romStdDev: 2.0,
      meanDuration: 2.03,
      tempoStdDev: 0.05,
      concentricMean: 1.0,
      eccentricMean: 1.0,
      peakRelativeDrift: 6.1,
      stabilityStatus: 'STRICT_STABILITY'
    }
  };
  await mobilePage.evaluate((set) => {
    window.dispatchEvent(new CustomEvent('formcoach_test_flow', {
      detail: { flow: 'results', set }
    }));
  }, curlSet);
  await mobilePage.waitForTimeout(600);
  await mobilePage.screenshot({ path: path.join(SCREENSHOT_DIR, 'formcoach-06-mobile-results-curl.png') });

  // Screenshot 7: Shoulder Press Results View with Bilateral Asymmetry & Lockout
  const pressSet = {
    id: 'set_press_1',
    exercise: 'shoulderPress',
    view: 'front',
    date: new Date().toISOString(),
    reps: [
      { index: 1, startTime: 0, inflectionTime: 1.0, endTime: 2.0, duration: 2.0, concentricDuration: 1.0, eccentricDuration: 1.0, primaryROM: 168, secondaryROM: 4, confidence: 0.98 },
      { index: 2, startTime: 2.2, inflectionTime: 3.2, endTime: 4.2, duration: 2.0, concentricDuration: 1.0, eccentricDuration: 1.0, primaryROM: 165, secondaryROM: 5, confidence: 0.98 },
      { index: 3, startTime: 4.5, inflectionTime: 5.5, endTime: 6.6, duration: 2.1, concentricDuration: 1.0, eccentricDuration: 1.1, primaryROM: 162, secondaryROM: 4, confidence: 0.97 }
    ],
    analysis: {
      overallScore: 95,
      romScore: 96,
      consistencyScore: 94,
      tempoScore: 93,
      symmetryScore: 96,
      primaryObservation: 'Symmetrical overhead lockout within ~4.3° bilateral variance across all reps.',
      observations: [
        {
          id: 'press.lockout.symmetry',
          title: 'Symmetrical Overhead Lockout',
          detail: 'Left and right arms moved symmetrically within ~4.3° variance.',
          evidence: 'Bilateral alignment verified from measured landmarks.',
          severity: 'positive',
          affectedReps: [1, 2, 3]
        }
      ],
      repCount: 3,
      meanROM: 165,
      romStdDev: 3.0,
      meanDuration: 2.03,
      tempoStdDev: 0.05,
      concentricMean: 1.0,
      eccentricMean: 1.0,
      meanAsymmetry: 4.3,
      stabilityStatus: 'STRICT_STABILITY'
    }
  };
  await mobilePage.evaluate((set) => {
    window.dispatchEvent(new CustomEvent('formcoach_test_flow', {
      detail: { flow: 'results', set }
    }));
  }, pressSet);
  await mobilePage.waitForTimeout(600);
  await mobilePage.screenshot({ path: path.join(SCREENSHOT_DIR, 'formcoach-07-mobile-results-press.png') });

  // Screenshot 8: Workout Summary View with Cross-Set Fatigue Meter
  const sessionSets = [
    squatSet,
    { ...squatSet, id: 'set_squat_2', analysis: { ...squatSet.analysis, meanROM: 86, meanDuration: 2.5, overallScore: 91 } },
    { ...squatSet, id: 'set_squat_3', analysis: { ...squatSet.analysis, meanROM: 91, meanDuration: 2.8, overallScore: 85 } }
  ];
  await mobilePage.evaluate((sessionSets) => {
    window.dispatchEvent(new CustomEvent('formcoach_test_flow', {
      detail: { flow: 'summary', sessionSets }
    }));
  }, sessionSets);
  await mobilePage.waitForTimeout(600);
  await mobilePage.screenshot({ path: path.join(SCREENSHOT_DIR, 'formcoach-08-mobile-workout-summary.png') });

  // 2. Desktop Viewport (1280x800)
  const desktopContext = await browser.newContext({
    viewport: { width: 1280, height: 800 }
  });
  const desktopPage = await desktopContext.newPage();
  await desktopPage.goto('http://localhost:3000');
  await desktopPage.screenshot({ path: path.join(SCREENSHOT_DIR, 'formcoach-09-desktop-routine.png') });

  await desktopPage.evaluate((set) => {
    window.dispatchEvent(new CustomEvent('formcoach_test_flow', {
      detail: { flow: 'results', set }
    }));
  }, squatSet);
  await desktopPage.waitForTimeout(500);
  await desktopPage.screenshot({ path: path.join(SCREENSHOT_DIR, 'formcoach-10-desktop-results.png') });

  await desktopContext.close();
  await mobileContext.close();
  await browser.close();

  console.log('🎉 FormCoach Complete Visual Audit finished with 10 pristine screenshots!');
}

runVisualAudit().catch(err => {
  console.error(err);
  process.exit(1);
});
