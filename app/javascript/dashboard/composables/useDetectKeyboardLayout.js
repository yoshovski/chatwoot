import { LAYOUT_QWERTY } from 'shared/helpers/KeyboardHelpers';

/**
 * Detects the keyboard layout using the modern navigator.keyboard API.
 * @returns {Promise<string>} A promise that resolves to the detected keyboard layout.
 */
async function detect() {
  const map = await navigator.keyboard.getLayoutMap();
  const q = map.get('KeyQ');
  const w = map.get('KeyW');
  const e = map.get('KeyE');
  const r = map.get('KeyR');
  const t = map.get('KeyT');
  const y = map.get('KeyY');

  return [q, w, e, r, t, y].join('').toUpperCase();
}

/**
 * Uses the keyboard layout API when available, otherwise defaults to QWERTY.
 * Never focus a temporary input: it can trigger password AutoFill during page load.
 * @returns {Promise<string>} A promise that resolves to the detected keyboard layout.
 */
export async function useDetectKeyboardLayout() {
  const cachedLayout = window.cw_keyboard_layout;
  if (cachedLayout) {
    return cachedLayout;
  }

  const layout = navigator.keyboard?.getLayoutMap
    ? await detect()
    : LAYOUT_QWERTY;
  window.cw_keyboard_layout = layout;
  return layout;
}
