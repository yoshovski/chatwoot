<script setup>
import { reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { accentAttrs } from './playgroundAccent';

const props = defineProps({
  content: { type: String, default: '' },
  items: { type: Array, default: () => [] },
  buttonLabel: { type: String, default: '' },
  widgetColor: { type: String, default: '' },
  widgetTextColor: { type: String, default: '' },
});

const { t } = useI18n();
const values = reactive(
  Object.fromEntries(props.items.map(item => [item.name, '']))
);
const isSubmitted = ref(false);

// The playground never creates a contact: submitting only shows what the customer would see next.
const onSubmit = () => {
  isSubmitted.value = true;
};
</script>

<template>
  <div
    class="flex w-72 max-w-full flex-col gap-2 rounded-2xl bg-n-slate-3 p-4 text-sm text-n-slate-12"
  >
    <p class="m-0">{{ content }}</p>
    <p v-if="isSubmitted" class="m-0 font-medium" data-test="form-thanks">
      {{ t('CAPTAIN.PLAYGROUND.CUSTOMER_VIEW.FORM_THANKS') }}
    </p>
    <form v-else class="flex flex-col gap-2" @submit.prevent="onSubmit">
      <label
        v-for="item in items"
        :key="item.name"
        class="flex flex-col gap-1 font-medium"
      >
        {{ item.label }}
        <input
          v-model="values[item.name]"
          :type="item.type"
          :name="item.name"
          :placeholder="item.placeholder"
          :required="item.required"
          class="!mb-0 rounded-lg bg-n-background"
        />
      </label>
      <button
        type="submit"
        class="rounded-lg px-3 py-2 font-medium"
        v-bind="accentAttrs(widgetColor, widgetTextColor)"
      >
        {{ buttonLabel }}
      </button>
    </form>
  </div>
</template>
