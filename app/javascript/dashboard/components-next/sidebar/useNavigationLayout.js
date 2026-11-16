import { computed } from 'vue';
import { useWindowSize } from '@vueuse/core';

// U09 can consume the same shell breakpoints without changing conversation panes.
export const MOBILE_NAV_BREAKPOINT = 768;
export const EXPANDED_NAV_BREAKPOINT = 1280;

export const useNavigationLayout = () => {
  const { width } = useWindowSize();
  return {
    isMobile: computed(() => width.value < MOBILE_NAV_BREAKPOINT),
    isCompact: computed(
      () =>
        width.value >= MOBILE_NAV_BREAKPOINT &&
        width.value < EXPANDED_NAV_BREAKPOINT
    ),
  };
};
