<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { getWidgetForegroundColor } from 'shared/helpers/colorHelper';
import ColorPicker from 'dashboard/components-next/colorpicker/ColorPicker.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const form = defineModel('form', { type: Object, required: true });

const { t } = useI18n();

const palette = computed(() => [
  {
    name: t('INBOX_MGMT.WIDGET_SETTINGS.COLORS.PALETTE.MINT'),
    hex: '#dcf4eb',
    swatchClass: 'bg-[#dcf4eb] text-slate-900',
  },
  {
    name: t('INBOX_MGMT.WIDGET_SETTINGS.COLORS.PALETTE.NAVY'),
    hex: '#192b45',
    swatchClass: 'bg-[#192b45] text-white',
  },
  {
    name: t('INBOX_MGMT.WIDGET_SETTINGS.COLORS.PALETTE.BLUE'),
    hex: '#20545a',
    swatchClass: 'bg-[#20545a] text-white',
  },
  {
    name: t('INBOX_MGMT.WIDGET_SETTINGS.COLORS.PALETTE.VIOLET'),
    hex: '#54446a',
    swatchClass: 'bg-[#54446a] text-white',
  },
  {
    name: t('INBOX_MGMT.WIDGET_SETTINGS.COLORS.PALETTE.ROSE'),
    hex: '#754050',
    swatchClass: 'bg-[#754050] text-white',
  },
  {
    name: t('INBOX_MGMT.WIDGET_SETTINGS.COLORS.PALETTE.CHARCOAL'),
    hex: '#353a40',
    swatchClass: 'bg-[#353a40] text-white',
  },
]);

const isSelected = hex => form.value.widgetColor.toLowerCase() === hex;
const isCustom = computed(
  () => !palette.value.some(({ hex }) => isSelected(hex))
);
const automaticColor = computed(() =>
  getWidgetForegroundColor(form.value.widgetColor)
);

const textColor = computed({
  get: () =>
    form.value.isWidgetTextColorCustom
      ? form.value.widgetTextColor
      : automaticColor.value,
  set: color => {
    form.value.widgetTextColor = color;
    form.value.isWidgetTextColorCustom = true;
  },
});

const iconColor = computed({
  get: () =>
    form.value.isWidgetIconColorCustom
      ? form.value.widgetIconColor
      : automaticColor.value,
  set: color => {
    form.value.widgetIconColor = color;
    form.value.isWidgetIconColorCustom = true;
  },
});

const resetTextColor = () => {
  form.value.widgetTextColor = automaticColor.value;
  form.value.isWidgetTextColorCustom = false;
};

const resetIconColor = () => {
  form.value.widgetIconColor = automaticColor.value;
  form.value.isWidgetIconColorCustom = false;
};
</script>

<template>
  <fieldset class="m-0 flex min-w-0 flex-col gap-2 border-0 p-0">
    <legend class="mb-2 p-0 text-sm font-medium text-n-slate-12">
      {{ t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.WIDGET_COLOR.LABEL') }}
    </legend>
    <div class="grid grid-cols-3 gap-2 sm:grid-cols-6">
      <button
        v-for="color in palette"
        :key="color.hex"
        type="button"
        :aria-pressed="isSelected(color.hex)"
        class="flex min-w-0 flex-col items-center gap-2.5 rounded-xl border px-1 py-3 text-center text-xs font-medium leading-tight text-n-slate-12 transition-colors hover:border-n-strong hover:bg-n-alpha-1 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-blue-9"
        :class="
          isSelected(color.hex)
            ? 'border-n-blue-8 bg-n-blue-2'
            : 'border-n-weak bg-n-solid-2'
        "
        @click="form.widgetColor = color.hex"
      >
        <span
          class="flex size-12 shrink-0 items-center justify-center rounded-full shadow-sm ring-1 ring-inset ring-black/10 sm:size-14"
          :class="color.swatchClass"
          aria-hidden="true"
        >
          <Icon
            v-if="isSelected(color.hex)"
            icon="i-lucide-check"
            class="size-5"
          />
        </span>
        <span class="break-words">{{ color.name }}</span>
      </button>
    </div>

    <details class="group mt-2 border-t border-n-weak pt-2">
      <summary
        class="flex min-h-9 cursor-pointer list-none items-center gap-1.5 rounded-md text-sm font-medium text-n-blue-11 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-blue-9 [&::-webkit-details-marker]:hidden"
      >
        <Icon
          icon="i-lucide-chevron-right"
          class="size-4 rtl:rotate-180 group-open:rotate-90"
        />
        {{ t('INBOX_MGMT.WIDGET_SETTINGS.COLORS.CUSTOMIZE') }}
        <span
          v-if="isCustom"
          class="ms-1 rounded-full bg-n-alpha-1 px-2 py-0.5 text-xs text-n-slate-11"
        >
          {{ t('INBOX_MGMT.WIDGET_SETTINGS.COLORS.CUSTOM') }}
        </span>
      </summary>
      <div
        class="mt-1 grid gap-3 rounded-lg border border-n-weak bg-n-alpha-1 p-3 sm:grid-cols-3"
      >
        <fieldset class="m-0 flex min-w-0 flex-col gap-1 border-0 p-0">
          <legend class="mb-1 p-0 text-sm font-medium text-n-slate-12">
            {{ t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.WIDGET_COLOR.LABEL') }}
          </legend>
          <ColorPicker v-model="form.widgetColor" />
        </fieldset>
        <fieldset class="m-0 flex min-w-0 flex-col gap-1 border-0 p-0">
          <legend class="mb-1 p-0 text-sm font-medium text-n-slate-12">
            {{
              t('INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_TEXT_COLOR')
            }}
          </legend>
          <ColorPicker v-model="textColor" />
          <button
            v-if="form.isWidgetTextColorCustom"
            type="button"
            class="self-start rounded text-xs font-medium text-n-blue-11 hover:underline"
            @click="resetTextColor"
          >
            {{ t('INBOX_MGMT.WIDGET_SETTINGS.COLORS.AUTOMATIC') }}
          </button>
        </fieldset>
        <fieldset class="m-0 flex min-w-0 flex-col gap-1 border-0 p-0">
          <legend class="mb-1 p-0 text-sm font-medium text-n-slate-12">
            {{
              t('INBOX_MGMT.WIDGET_BUILDER.WIDGET_OPTIONS.WIDGET_ICON_COLOR')
            }}
          </legend>
          <ColorPicker v-model="iconColor" />
          <button
            v-if="form.isWidgetIconColorCustom"
            type="button"
            class="self-start rounded text-xs font-medium text-n-blue-11 hover:underline"
            @click="resetIconColor"
          >
            {{ t('INBOX_MGMT.WIDGET_SETTINGS.COLORS.AUTOMATIC') }}
          </button>
        </fieldset>
      </div>
    </details>
  </fieldset>
</template>
