import { escapeHtml } from 'shared/helpers/HTMLSanitizer';

/**
 * Formats an instruction string containing tool links ([@Title](tool://tool_id))
 * into HTML with styled tool chips, preserving markdown structure like ordered and unordered lists.
 *
 * @param {string} instruction - The scenario instruction markdown
 * @param {Array<Object>} tools - Available tools from captainTools
 * @param {Object} options - Options including formatMessage and unavailableText
 * @returns {string} - Rendered HTML with tool chips
 */
export const formatInstructionWithToolChips = (
  instruction,
  tools = [],
  {
    formatMessage,
    unavailableText = "This tool isn't available for this assistant",
  } = {}
) => {
  if (!instruction) return '';

  const html = formatMessage ? formatMessage(instruction, false) : instruction;

  return html.replace(
    /<a\b[^>]*href="tool:\/\/([^"/?#]+)"[^>]*>[\s\S]*?<\/a>/gi,
    (match, toolId) => {
      const tool = (tools || []).find(t => t.id === toolId);
      const isAvailable = Boolean(tool);
      const title = tool?.title || toolId;
      const emoji = tool?.emoji || '';
      const tooltip = isAvailable ? tool?.description || '' : unavailableText;

      if (isAvailable) {
        return `<span class="inline-flex items-center gap-1 px-2 py-0.5 mx-0.5 rounded-full text-xs font-medium align-middle bg-n-iris-3 text-n-iris-11 border border-n-iris-4 select-none cursor-default" data-tool-chip data-tool-id="${escapeHtml(
          toolId
        )}" title="${escapeHtml(tooltip)}">${
          emoji ? `<span class="tool-emoji leading-none">${emoji}</span>` : ''
        }<span class="tool-title">${escapeHtml(title)}</span></span>`;
      }

      return `<span class="inline-flex items-center gap-1 px-2 py-0.5 mx-0.5 rounded-full text-xs font-medium align-middle bg-n-alpha-2 text-n-slate-11 border border-n-weak select-none cursor-default" data-tool-chip data-tool-id="${escapeHtml(
        toolId
      )}" title="${escapeHtml(tooltip)}"><span class="tool-title">${escapeHtml(
        toolId
      )}</span></span>`;
    }
  );
};
