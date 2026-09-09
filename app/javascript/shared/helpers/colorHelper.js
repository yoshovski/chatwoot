import { toHex, mix, getLuminance, getContrast } from 'color2k';

export const isWidgetColorLighter = color => {
  const colorWithoutHash = color.replace('#', '');
  const colorToCheck =
    colorWithoutHash.length === 3
      ? colorWithoutHash
          .split('')
          .map(character => `${character}${character}`)
          .join('')
      : colorWithoutHash;
  const c_r = parseInt(colorToCheck.substr(0, 2), 16);
  const c_g = parseInt(colorToCheck.substr(2, 2), 16);
  const c_b = parseInt(colorToCheck.substr(4, 2), 16);
  const brightness = (c_r * 299 + c_g * 587 + c_b * 114) / 1000;
  return brightness > 225;
};

export const getWidgetForegroundColor = color =>
  isWidgetColorLighter(color) ? '#37546d' : '#FFFFFF';

// Buttons inside message bubbles are filled with the widget colour. When that colour is this
// light it disappears into the near-white bubble behind it, leaving what looks like bare text,
// so those installs get an outlined button instead.
export const shouldOutlineWidgetButton = color =>
  !color || isWidgetColorLighter(color);

export const adjustColorForContrast = (color, backgroundColor) => {
  const targetRatio = 3.1;
  const MAX_ITERATIONS = 20;
  let adjustedColor = color;

  for (let iteration = 0; iteration < MAX_ITERATIONS; iteration += 1) {
    const currentRatio = getContrast(adjustedColor, backgroundColor);
    if (currentRatio >= targetRatio) {
      break;
    }
    const adjustmentDirection =
      getLuminance(adjustedColor) < 0.5 ? '#fff' : '#151718';
    adjustedColor = mix(adjustedColor, adjustmentDirection, 0.05);
  }

  return toHex(adjustedColor);
};
