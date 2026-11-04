import { useDetectKeyboardLayout } from 'dashboard/composables/useDetectKeyboardLayout';
import {
  LAYOUT_QWERTY,
  LAYOUT_QWERTZ,
  LAYOUT_AZERTY,
} from 'shared/helpers/KeyboardHelpers';

describe('useDetectKeyboardLayout', () => {
  beforeEach(() => {
    window.cw_keyboard_layout = null;
  });

  it('returns cached layout if available', async () => {
    window.cw_keyboard_layout = LAYOUT_QWERTY;
    const layout = await useDetectKeyboardLayout();
    expect(layout).toBe(LAYOUT_QWERTY);
  });

  it('should detect QWERTY layout using modern method', async () => {
    navigator.keyboard = {
      getLayoutMap: vi.fn().mockResolvedValue(
        new Map([
          ['KeyQ', 'q'],
          ['KeyW', 'w'],
          ['KeyE', 'e'],
          ['KeyR', 'r'],
          ['KeyT', 't'],
          ['KeyY', 'y'],
        ])
      ),
    };

    const layout = await useDetectKeyboardLayout();
    expect(layout).toBe(LAYOUT_QWERTY);
  });

  it('should detect QWERTZ layout using modern method', async () => {
    navigator.keyboard = {
      getLayoutMap: vi.fn().mockResolvedValue(
        new Map([
          ['KeyQ', 'q'],
          ['KeyW', 'w'],
          ['KeyE', 'e'],
          ['KeyR', 'r'],
          ['KeyT', 't'],
          ['KeyY', 'z'],
        ])
      ),
    };

    const layout = await useDetectKeyboardLayout();
    expect(layout).toBe(LAYOUT_QWERTZ);
  });

  it('should detect AZERTY layout using modern method', async () => {
    navigator.keyboard = {
      getLayoutMap: vi.fn().mockResolvedValue(
        new Map([
          ['KeyQ', 'a'],
          ['KeyW', 'z'],
          ['KeyE', 'e'],
          ['KeyR', 'r'],
          ['KeyT', 't'],
          ['KeyY', 'y'],
        ])
      ),
    };

    const layout = await useDetectKeyboardLayout();
    expect(layout).toBe(LAYOUT_AZERTY);
  });

  it('defaults to QWERTY without creating or focusing an input when the API is unavailable', async () => {
    navigator.keyboard = undefined;
    const createElement = vi.spyOn(document, 'createElement');
    const focus = vi.spyOn(HTMLElement.prototype, 'focus');
    const activeElement = document.activeElement;

    const layout = await useDetectKeyboardLayout();
    expect(layout).toBe(LAYOUT_QWERTY);
    expect(createElement).not.toHaveBeenCalled();
    expect(focus).not.toHaveBeenCalled();
    expect(document.activeElement).toBe(activeElement);
  });

  it('should cache the detected layout', async () => {
    navigator.keyboard = {
      getLayoutMap: vi.fn().mockResolvedValue(
        new Map([
          ['KeyQ', 'q'],
          ['KeyW', 'w'],
          ['KeyE', 'e'],
          ['KeyR', 'r'],
          ['KeyT', 't'],
          ['KeyY', 'y'],
        ])
      ),
    };

    const layout = await useDetectKeyboardLayout();
    expect(layout).toBe(LAYOUT_QWERTY);

    const layoutAgain = await useDetectKeyboardLayout();
    expect(layoutAgain).toBe(LAYOUT_QWERTY);
    expect(navigator.keyboard.getLayoutMap).toHaveBeenCalledTimes(1);
  });
});
