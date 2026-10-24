// Only the explicit screenshot-link form from knowledge answers becomes an image.
const SCREENSHOT_LINE =
  /^[ \t]*\[Screenshot: ([^\]\n]+)\]\((https:\/\/[^\s)]+)\)[ \t]*$/gm;
const MAX_SCREENSHOTS = 2;

export const extractScreenshots = (text = '') => {
  const screenshots = [];
  const seen = new Set();
  const prose = (text || '').replace(SCREENSHOT_LINE, (line, caption, url) => {
    if (!seen.has(url) && screenshots.length < MAX_SCREENSHOTS) {
      screenshots.push({ caption, url });
      seen.add(url);
      return '';
    }
    return seen.has(url) ? '' : line;
  });
  return { text: prose.replace(/\n{3,}/g, '\n\n').trim(), screenshots };
};
