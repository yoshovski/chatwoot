import { computed, inject } from 'vue';

// The shell owns a section title only when its persistent header is present.
export const sectionHeadingKey = Symbol('sectionHeading');
export function useSectionHeadingMatches(getTitle) {
  const heading = inject(sectionHeadingKey, null);
  return computed(
    () => Boolean(heading?.value) && heading.value === getTitle()
  );
}
