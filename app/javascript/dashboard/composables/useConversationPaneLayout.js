import { computed } from 'vue';
import { useElementSize } from '@vueuse/core';

// Widths in rem, so browser zoom and the root font size are respected. LIST
// and DETAILS match the widest Tailwind widths of those panes; GAP is the
// space between the thread card and the docked details.
export const CONVERSATION_PANE_REM = {
  LIST: 22.5,
  DETAILS: 22,
  GAP: 0.75,
  READABLE_THREAD: 25,
};

// Decides which panes fit beside a readable thread in the available width.
// A width of 0 means "not measured yet": keep the list and float the details.
export const getConversationPaneLayout = ({
  availableRem,
  isOnExpandedLayout,
}) => {
  const { LIST, DETAILS, GAP, READABLE_THREAD } = CONVERSATION_PANE_REM;
  if (!availableRem) {
    return { isSinglePane: isOnExpandedLayout, canDockDetails: false };
  }
  const isSinglePane =
    isOnExpandedLayout || availableRem < LIST + READABLE_THREAD;
  const threadRem = isSinglePane ? availableRem : availableRem - LIST;
  return {
    isSinglePane,
    canDockDetails: threadRem - GAP - DETAILS >= READABLE_THREAD,
  };
};

export function useConversationPaneLayout(containerRef, isOnExpandedLayout) {
  const { width } = useElementSize(containerRef);

  const layout = computed(() => {
    const remInPx = parseFloat(
      getComputedStyle(document.documentElement).fontSize
    );
    return getConversationPaneLayout({
      availableRem: width.value / remInPx,
      isOnExpandedLayout: isOnExpandedLayout.value,
    });
  });

  return {
    isSinglePane: computed(() => layout.value.isSinglePane),
    canDockDetails: computed(() => layout.value.canDockDetails),
  };
}
