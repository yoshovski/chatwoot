import { addClasses, removeClasses } from './DOMHelpers';
import { initOnEvents } from 'shared/helpers/AudioNotificationHelper';

// The host page owns the one audio context, so a reply sounds at most once however many
// bubbles, tabs or socket deliveries reach the widget.
const MUTE_KEY = 'cw_attention_muted';
const SOUND_COOLDOWN_MS = 30000;
const HIGHLIGHT_MS = 1600;
const FORM_FIELDS =
  'input, textarea, select, [contenteditable=""], [contenteditable="true"]';

let audioContext;
let lastSoundAt = 0;
let highlightTimer;
const playedReplies = new Set();

const readMuted = () => {
  try {
    return window.localStorage.getItem(MUTE_KEY) === '1';
  } catch {
    return false;
  }
};

let muted = readMuted();

export const hostAttentionState = () => {
  const active = document.activeElement;
  return {
    visible: document.visibilityState === 'visible',
    formActive: Boolean(
      active && active.tagName !== 'IFRAME' && active.matches(FORM_FIELDS)
    ),
    muted,
    audioReady: audioContext?.state === 'running',
  };
};

// Browsers only allow audio after a gesture on the host page. Until then the reply stays
// visual; a blocked sound is dropped, never queued for a later click.
export const unlockAudio = onChange => {
  const unlock = () => {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext) return;
    audioContext = audioContext || new AudioContext();
    audioContext.resume().then(() => {
      initOnEvents.forEach(event =>
        document.removeEventListener(event, unlock, true)
      );
      onChange();
    });
  };
  initOnEvents.forEach(event => document.addEventListener(event, unlock, true));
};

// An original short, soft "pop": a sine that rises a fifth with a quick attack and a short tail.
const playPop = () => {
  const now = audioContext.currentTime;
  const gain = audioContext.createGain();
  gain.gain.setValueAtTime(0.0001, now);
  gain.gain.exponentialRampToValueAtTime(0.16, now + 0.008);
  gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.24);
  gain.connect(audioContext.destination);

  [
    [1, 1],
    [2, 0.18],
  ].forEach(([harmonic, level]) => {
    const partial = audioContext.createGain();
    partial.gain.value = level;
    partial.connect(gain);
    const oscillator = audioContext.createOscillator();
    oscillator.type = 'sine';
    oscillator.frequency.setValueAtTime(520 * harmonic, now);
    oscillator.frequency.exponentialRampToValueAtTime(
      780 * harmonic,
      now + 0.07
    );
    oscillator.connect(partial);
    oscillator.start(now);
    oscillator.stop(now + 0.26);
  });
};

export const playReplySound = replyKey => {
  if (muted || audioContext?.state !== 'running') return false;
  if (playedReplies.has(replyKey)) return false;
  if (Date.now() - lastSoundAt < SOUND_COOLDOWN_MS) return false;
  playedReplies.add(replyKey);
  lastSoundAt = Date.now();
  playPop();
  return true;
};

export const setMuted = value => {
  muted = Boolean(value);
  try {
    window.localStorage.setItem(MUTE_KEY, muted ? '1' : '0');
  } catch {
    // Storage can be blocked on the host page; the choice lasts for this page view.
  }
};

export const highlightLauncher = bubble => {
  clearTimeout(highlightTimer);
  removeClasses(bubble, 'woot-widget-bubble--attention');
  // Restart the animation when a second cue follows a first one.
  // eslint-disable-next-line no-unused-expressions
  bubble.offsetWidth;
  addClasses(bubble, 'woot-widget-bubble--attention');
  highlightTimer = setTimeout(
    () => removeClasses(bubble, 'woot-widget-bubble--attention'),
    HIGHLIGHT_MS
  );
};

export const watchHostAttention = onChange => {
  document.addEventListener('visibilitychange', onChange);
  // focusout fires before the next element gets focus, so read the state after it settles.
  const onFocus = () => setTimeout(onChange, 0);
  document.addEventListener('focusin', onFocus);
  document.addEventListener('focusout', onFocus);
  unlockAudio(onChange);
};
