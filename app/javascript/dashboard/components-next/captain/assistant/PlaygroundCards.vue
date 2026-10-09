<script setup>
import { useI18n } from 'vue-i18n';
import { accentAttrs } from './playgroundAccent';

defineProps({
  items: { type: Array, default: () => [] },
  widgetColor: { type: String, default: '' },
  widgetTextColor: { type: String, default: '' },
});

const { t } = useI18n();

// Product cards carry link actions; article items (products without an image) carry a single link.
const actionsFor = item => {
  if (item.actions?.length) return item.actions.filter(a => a.uri);
  return item.link
    ? [
        {
          text: t('CAPTAIN.PLAYGROUND.CUSTOMER_VIEW.VIEW_PRODUCT'),
          uri: item.link,
        },
      ]
    : [];
};
</script>

<template>
  <div
    class="flex max-w-full snap-x snap-mandatory items-stretch gap-2 overflow-x-auto pb-1"
    data-test="playground-cards"
  >
    <div
      v-for="item in items"
      :key="item.title"
      class="flex w-56 shrink-0 snap-start flex-col overflow-hidden rounded-xl bg-n-slate-3 text-n-slate-12"
    >
      <img
        v-if="item.media_url"
        :src="item.media_url"
        alt=""
        class="h-32 w-full object-cover"
      />
      <div class="flex flex-1 flex-col gap-1 p-3">
        <h4 class="m-0 text-sm font-medium">{{ item.title }}</h4>
        <p v-if="item.description" class="m-0 line-clamp-3 text-n-slate-11">
          {{ item.description }}
        </p>
        <div class="mt-auto flex flex-col gap-1 pt-2">
          <a
            v-for="action in actionsFor(item)"
            :key="action.uri"
            :href="action.uri"
            target="_blank"
            rel="noopener noreferrer"
            class="rounded-lg px-3 py-1.5 text-center text-sm font-medium"
            v-bind="accentAttrs(widgetColor, widgetTextColor)"
          >
            {{ action.text }}
          </a>
        </div>
      </div>
    </div>
  </div>
</template>
