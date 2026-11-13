<script setup>
// A static copy of the real chat widget (conversation view) answering an example question: the same header,
// bubbles, product card, composer, footer and launcher as `app/javascript/widget`, in the widget's system font and
// its default colours. Keep it in step when the widget's conversation view changes.
import { computed } from 'vue';
import { useStore } from 'vuex';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const store = useStore();
const installationName = computed(
  () => store.getters['globalConfig/get'].installationName
);
</script>

<template>
  <div class="flex flex-col items-end gap-4 font-sans" aria-hidden="true">
    <span
      class="self-start rounded-full bg-white/15 px-2.5 py-0.5 text-xs font-medium text-white"
    >
      {{ $t('AUTH_WIDGET_PREVIEW.EXAMPLE') }}
    </span>
    <div
      class="flex w-full flex-col overflow-hidden rounded-2xl bg-white shadow-[0_5px_40px_rgba(0,0,0,0.16)]"
    >
      <div class="flex items-center gap-3 bg-[#fafafa] px-4 py-3">
        <Icon icon="i-lucide-chevron-left" class="size-5 text-[#1c2024]" />
        <div class="min-w-0">
          <p class="mb-0 truncate text-base text-[#1c2024]">
            {{ $t('AUTH_WIDGET_PREVIEW.SHOP') }}
          </p>
          <p class="mb-0 text-xs text-[#60646c]">
            {{ $t('AUTH_WIDGET_PREVIEW.REPLY_TIME') }}
          </p>
        </div>
      </div>
      <div class="flex flex-col gap-1 px-4 pt-4 pb-3">
        <div class="mb-3 flex items-center gap-4 text-xs text-[#60646c]">
          <span class="h-px flex-1 bg-[#e8e8ec]" />
          {{ $t('AUTH_WIDGET_PREVIEW.TODAY') }}
          <span class="h-px flex-1 bg-[#e8e8ec]" />
        </div>
        <p
          class="mb-3 max-w-[78%] self-end rounded-[1.25rem] rounded-br-[0.25rem] bg-[#1f93ff] px-4 py-3 text-sm leading-normal text-white shadow-[0_0.25rem_6px_rgba(50,50,93,0.08),0_1px_3px_rgba(0,0,0,0.05)]"
        >
          {{ $t('AUTH_WIDGET_PREVIEW.QUESTION') }}
        </p>
        <div class="flex items-end gap-2">
          <span
            class="flex size-6 shrink-0 items-center justify-center rounded-full bg-[#1f93ff] text-white"
          >
            <Icon icon="i-lucide-bot" class="size-3.5" />
          </span>
          <div class="flex min-w-0 flex-col items-start gap-1">
            <p
              class="mb-0 max-w-[16rem] rounded-[1.25rem] rounded-bl-[0.25rem] bg-[#f0f0f3] px-4 py-3 text-sm leading-normal text-[#1c2024]"
            >
              {{ $t('AUTH_WIDGET_PREVIEW.ANSWER') }}
            </p>
            <div
              class="flex w-48 flex-col rounded-[1.25rem] rounded-tl-[0.25rem] bg-[#fcfcfd] px-4 py-3 text-sm shadow-[0_0.25rem_6px_rgba(50,50,93,0.08),0_1px_3px_rgba(0,0,0,0.05)]"
            >
              <p class="mb-1 text-base font-medium text-[#1c2024]">
                {{ $t('AUTH_WIDGET_PREVIEW.PRODUCT.TITLE') }}
              </p>
              <p class="mb-2 text-[#60646c]">
                {{ $t('AUTH_WIDGET_PREVIEW.PRODUCT.DESCRIPTION') }}
              </p>
              <span
                class="rounded-lg bg-[#1f93ff] py-2 text-center text-sm text-white"
              >
                {{ $t('AUTH_WIDGET_PREVIEW.PRODUCT.CTA') }}
              </span>
            </div>
          </div>
        </div>
        <p class="mt-1 mb-0 ps-8 text-xs text-[#60646c]">
          {{ $t('AUTH_WIDGET_PREVIEW.AGENT') }}
        </p>
      </div>
      <div class="border-t border-[#e8e8ec] px-4 pt-3 pb-2">
        <p class="mb-2 text-sm text-[#8b8d98]">
          {{ $t('AUTH_WIDGET_PREVIEW.COMPOSER') }}
        </p>
        <div class="flex items-center gap-3 text-[#60646c]">
          <Icon icon="i-lucide-paperclip" class="size-4" />
          <Icon icon="i-lucide-smile" class="size-4" />
          <span
            class="ms-auto flex size-8 items-center justify-center rounded-full bg-[#f0f0f3]"
          >
            <Icon icon="i-lucide-send-horizontal" class="size-4" />
          </span>
        </div>
        <p class="mt-2 mb-0 text-center text-[0.6875rem] text-[#8b8d98]">
          {{ $t('AUTH_WIDGET_PREVIEW.POWERED_BY', { name: installationName }) }}
        </p>
      </div>
    </div>
    <span
      class="flex size-14 items-center justify-center rounded-full bg-[#1f93ff] text-white shadow-[0_4px_12px_rgba(0,0,0,0.16)]"
    >
      <Icon icon="i-lucide-x" class="size-6" />
    </span>
  </div>
</template>
