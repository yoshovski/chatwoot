<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import AddNewRulesInput from 'dashboard/components-next/captain/assistant/AddNewRulesInput.vue';

// Mirrors Captain::Assistant::MAX_HANDOFF_RULES and HANDOFF_RULE_LENGTH_LIMIT.
const MAX_RULES = 10;
const MAX_RULE_LENGTH = 300;
const PRESETS = ['LEGAL', 'FRUSTRATED', 'EMAIL', 'BILLING', 'REPEATED'];

const rules = defineModel({ type: Array, default: () => [] });
const { t } = useI18n();
const draft = ref('');

const presetText = key =>
  t(`CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.RULES.PRESETS.${key}.TEXT`);
// Presets already in the list are not offered again.
const presets = computed(() =>
  PRESETS.filter(key => !rules.value.includes(presetText(key)))
);
const canAdd = computed(() => rules.value.length < MAX_RULES);

const add = text => {
  if (!canAdd.value || rules.value.includes(text)) return;
  rules.value = [...rules.value, text];
};
const remove = index => {
  rules.value = rules.value.filter((_, position) => position !== index);
};
</script>

<template>
  <div class="flex flex-col gap-3 pt-2">
    <div v-if="canAdd && presets.length" class="flex flex-wrap gap-2">
      <button
        v-for="key in presets"
        :key="key"
        type="button"
        class="flex items-center gap-1.5 h-8 px-3 text-sm rounded-lg outline outline-1 outline-n-weak bg-n-solid-1 text-n-slate-12 hover:outline-n-strong"
        @click="add(presetText(key))"
      >
        <span
          class="i-lucide-plus size-3.5 text-n-slate-10"
          aria-hidden="true"
        />
        {{
          t(`CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.RULES.PRESETS.${key}.LABEL`)
        }}
      </button>
    </div>
    <ul v-if="rules.length" class="flex flex-col gap-2 p-0 m-0 list-none">
      <li
        v-for="(rule, index) in rules"
        :key="rule"
        class="flex items-start gap-2 px-3 py-2 text-sm rounded-lg bg-n-alpha-1 text-n-slate-12"
      >
        <span class="flex-1 min-w-0 break-words">{{ rule }}</span>
        <Button
          v-tooltip.top="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.RULES.REMOVE')"
          :aria-label="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.RULES.REMOVE')"
          icon="i-lucide-x"
          variant="ghost"
          color="slate"
          size="xs"
          @click="remove(index)"
        />
      </li>
    </ul>
    <AddNewRulesInput
      v-if="canAdd"
      v-model="draft"
      :placeholder="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.RULES.PLACEHOLDER')"
      :label="t('CAPTAIN.ASSISTANTS.SETTINGS.HANDOVER.RULES.ADD')"
      :max-length="MAX_RULE_LENGTH"
      @add="add"
    />
  </div>
</template>
