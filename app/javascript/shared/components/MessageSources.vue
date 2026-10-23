<script setup>
import { computed } from 'vue';

// The pages an AI agent answer relied on, listed at the foot of its bubble (widget, playground and agent view).
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
      return { ...source, host, initial: (host[0] || '?').toUpperCase() };
    })
);
</script>

<template>
  <nav
    v-if="links.length"
    class="flex flex-col gap-1 pt-2 mt-3 border-t border-n-weak"
    :aria-label="label"
  >
    <span class="text-xs text-n-slate-10">
      {{ label }}
    </span>
    <a
      v-for="link in links"
      :key="link.url"
      :href="link.url"
      target="_blank"
      rel="noopener noreferrer nofollow"
      class="flex items-center min-w-0 gap-2 px-1 py-1 -mx-1 rounded-lg text-n-slate-12 hover:bg-n-alpha-1 !no-underline"
    >
      <span
        class="inline-flex items-center justify-center rounded size-5 shrink-0 bg-n-alpha-2 text-n-slate-11 text-xxs font-medium"
        aria-hidden="true"
      >
        {{ link.initial }}
      </span>
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
</template>
