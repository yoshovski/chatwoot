<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import AddNewRulesDialog from 'dashboard/components-next/captain/assistant/AddNewRulesDialog.vue';
import RuleCard from 'dashboard/components-next/captain/assistant/RuleCard.vue';

// One short list of plain-language rules. Adding, editing and deleting a rule saves it at once.
const props = defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  items: { type: Array, default: () => [] },
  suggestions: { type: Array, default: () => [] },
  placeholder: { type: String, default: '' },
  addLabel: { type: String, required: true },
});

const emit = defineEmits(['update']);
const { t } = useI18n();
const newRule = ref('');

const rows = computed(() =>
  props.items.map((content, id) => ({ id, content }))
);
const openSuggestions = computed(() =>
  props.suggestions.filter(text => !props.items.includes(text)).slice(0, 4)
);

const add = content => emit('update', [...props.items, content]);
const edit = ({ id, content }) =>
  emit(
    'update',
    props.items.map((item, index) => (index === id ? content : item))
  );
const remove = id =>
  emit(
    'update',
    props.items.filter((_, index) => index !== id)
  );
</script>

<template>
  <section class="flex flex-col gap-3">
    <div class="flex items-start justify-between gap-3">
      <div class="flex flex-col gap-0.5">
        <h3 class="m-0 text-base font-semibold text-n-slate-12">
          {{ title }}
          <span
            v-if="items.length"
            class="ms-1 text-sm font-normal text-n-slate-10"
          >
            {{ items.length }}
          </span>
        </h3>
        <p v-if="description" class="m-0 text-sm text-n-slate-11">
          {{ description }}
        </p>
      </div>
      <AddNewRulesDialog
        v-model="newRule"
        :placeholder="placeholder"
        :button-label="addLabel"
        :confirm-label="
          t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.ADD.NEW.CREATE')
        "
        :cancel-label="
          t('CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.ADD.NEW.CANCEL')
        "
        @add="add"
      />
    </div>
    <div v-if="rows.length" class="flex flex-col gap-2">
      <RuleCard
        v-for="row in rows"
        :id="row.id"
        :key="`${row.id}-${row.content}`"
        :content="row.content"
        @edit="edit"
        @delete="remove"
      />
    </div>
    <div
      v-if="!rows.length && openSuggestions.length"
      class="flex flex-wrap gap-2"
    >
      <button
        v-for="text in openSuggestions"
        :key="text"
        type="button"
        class="flex items-center gap-1.5 px-3 py-1.5 text-sm text-start rounded-lg outline outline-1 outline-dashed outline-n-strong text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-1"
        @click="add(text)"
      >
        <span class="i-lucide-plus size-3.5 shrink-0" aria-hidden="true" />
        {{ text }}
      </button>
    </div>
  </section>
</template>
