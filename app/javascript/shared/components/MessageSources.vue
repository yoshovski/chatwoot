<script setup>
import { computed } from 'vue';

// A compact disclosure keeps references available without crowding the answer.
const props = defineProps({
  sources: { type: Array, default: () => [] },
  label: { type: String, required: true },
});

const hostOf = url => {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return '';
  }
};

const links = computed(() =>
  props.sources
    .filter(source => source?.url)
    .map(source => {
      const host = hostOf(source.url);
      return { ...source, host };
    })
);
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <details v-if="links.length" class="group/sources mt-3">
    <summary
      class="inline-flex cursor-pointer list-none items-center gap-2 rounded-full border border-solid border-n-weak bg-n-solid-1 px-2.5 py-1.5 text-xs text-n-slate-12 [&::-webkit-details-marker]:hidden"
    >
      <span
        class="flex size-5 items-center justify-center rounded-full bg-n-alpha-2"
        aria-hidden="true"
      >
        <i class="i-lucide-files size-3.5" />
      </span>
      {{ label }}
      <span class="text-n-slate-11">{{ links.length }}</span>
      <i
        class="i-lucide-chevron-down size-3.5 transition-transform group-open/sources:rotate-180"
        aria-hidden="true"
      />
    </summary>
    <nav class="mt-2 flex flex-col gap-1.5" :aria-label="label">
      <a
        v-for="link in links"
        :key="link.url"
        :href="link.url"
        target="_blank"
        rel="noopener noreferrer nofollow"
        class="flex min-w-0 items-center gap-2 rounded-xl border border-solid border-n-weak bg-n-solid-1 px-3 py-2 text-n-slate-12 hover:bg-n-alpha-1 !no-underline"
      >
        <i
          class="i-lucide-file-text size-4 shrink-0 text-n-slate-11"
          aria-hidden="true"
        />
        <span class="flex flex-col flex-1 min-w-0 leading-tight">
          <span class="text-xs font-medium truncate">{{ link.title }}</span>
          <span v-if="link.host" class="text-xxs truncate text-n-slate-10">
            {{ link.host }}
          </span>
        </span>
        <span
          class="i-lucide-external-link size-3.5 shrink-0 text-n-slate-10"
          aria-hidden="true"
        />
      </a>
    </nav>
  </details>
</template>
