const CAPTAIN_WORD = /(?<![\p{L}\p{N}_])Captain(?![\p{L}\p{N}_])/gu;
const DEFAULT_NAME = 'Captain';

/**
 * Replaces the whole word "Captain" in every string value of a messages tree
 * with the configured AI agent product name. Keys are never touched.
 * @param {*} messages - i18n messages (object, array or string)
 * @param {string} brandName - the configured product name
 * @returns {*} - the same shape with the product name applied
 */
export const applyCaptainBrand = (messages, brandName) => {
  if (!brandName || brandName === DEFAULT_NAME) return messages;

  const walk = node => {
    if (typeof node === 'string') {
      return node.replace(CAPTAIN_WORD, () => brandName);
    }
    if (Array.isArray(node)) return node.map(walk);
    if (node && typeof node === 'object') {
      return Object.fromEntries(
        Object.entries(node).map(([key, value]) => [key, walk(value)])
      );
    }
    return node;
  };

  return walk(messages);
};

export default applyCaptainBrand;
