<script setup>
import HeaderActions from './HeaderActions.vue';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';

defineProps({
  websiteName: { type: String, default: '' },
  avatarUrl: {
    type: String,
    default: '',
  },
  introHeading: {
    type: String,
    default: '',
  },
  introBody: {
    type: String,
    default: '',
  },
  showPopoutButton: {
    type: Boolean,
    default: false,
  },
});

const { formatMessage } = useMessageFormatter();
</script>

<template>
  <!-- A welcome state is useful even before an inbox has custom intro copy. -->
  <header
    class="header-expanded relative isolate box-border w-full shrink-0 overflow-hidden bg-[var(--widget-color)] px-6 pt-6 pb-14 text-[var(--widget-text-color)] [&_.actions_svg]:!text-current"
  >
    <div
      aria-hidden="true"
      class="pointer-events-none absolute -top-24 -end-20 -z-10 size-72 rounded-full border-[40px] border-current opacity-[0.06]"
    />
    <div class="flex items-center justify-between gap-3">
      <div class="flex min-w-0 items-center gap-3">
        <img
          v-if="avatarUrl"
          class="object-cover size-10 rounded-xl bg-white"
          :src="avatarUrl"
          :alt="websiteName"
        />
        <span
          v-else
          class="flex size-10 shrink-0 items-center justify-center rounded-xl bg-white/15"
        >
          <i class="i-lucide-messages-square size-5" aria-hidden="true" />
        </span>
        <span class="truncate text-sm font-semibold">{{ websiteName }}</span>
      </div>
      <HeaderActions
        :show-popout-button="showPopoutButton"
        :show-end-conversation-button="false"
      />
    </div>
    <h2
      v-dompurify-html="introHeading"
      class="mt-8 mb-2 text-3xl font-semibold tracking-tight leading-tight line-clamp-4"
    />
    <p
      v-dompurify-html="formatMessage(introBody)"
      class="text-base leading-relaxed opacity-90 [&_a]:underline line-clamp-6"
    />
  </header>
</template>
