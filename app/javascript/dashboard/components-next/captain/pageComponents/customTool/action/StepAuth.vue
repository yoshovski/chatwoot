<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import { AUTH_TYPES } from './actionForm';

// How one request authenticates: its own type, or the auth of an earlier request.
const props = defineProps({
  // Earlier requests whose auth this one can reuse: [{ key, number }].
  sameAsOptions: { type: Array, default: () => [] },
  // The saved secret is never sent back; the field shows "Saved" until the admin replaces it.
  configured: { type: Boolean, default: false },
});

const auth = defineModel('auth', { type: Object, required: true });
const { t } = useI18n();

const SAME_AS_PREFIX = 'same:';
const isReplacing = ref(!props.configured);

const options = computed(() => [
  ...AUTH_TYPES.map(type => ({
    value: type,
    label: t(`CAPTAIN.CUSTOM_TOOLS.FORM.AUTH_TYPES.${type.toUpperCase()}`),
  })),
  ...props.sameAsOptions.map(({ key, number }) => ({
    value: `${SAME_AS_PREFIX}${key}`,
    label: t('CAPTAIN.CUSTOM_TOOLS.ACTION.AUTH.SAME_AS', { number }),
  })),
]);

const selected = computed({
  get: () =>
    auth.value.same_as
      ? `${SAME_AS_PREFIX}${auth.value.same_as}`
      : auth.value.type || 'none',
  set: value => {
    isReplacing.value = true;
    auth.value = value.startsWith(SAME_AS_PREFIX)
      ? { same_as: value.slice(SAME_AS_PREFIX.length) }
      : { type: value };
  },
});

const showSaved = computed(() => props.configured && !isReplacing.value);
</script>

<template>
  <div class="grid items-start gap-2 sm:grid-cols-[11rem_minmax(0,1fr)]">
    <ComboBox
      v-model="selected"
      :options="options"
      :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.AUTH.LABEL')"
      class="[&>div>button]:bg-n-alpha-black2"
    />
    <div
      v-if="!auth.same_as && auth.type !== 'none'"
      class="flex flex-col gap-2"
    >
      <Input
        v-if="auth.type === 'basic'"
        v-model="auth.username"
        :placeholder="t('CAPTAIN.CUSTOM_TOOLS.FORM.AUTH_CONFIG.USERNAME')"
      />
      <Input
        v-if="auth.type === 'api_key'"
        v-model="auth.name"
        :placeholder="
          t('CAPTAIN.CUSTOM_TOOLS.FORM.AUTH_CONFIG.API_KEY_PLACEHOLDER')
        "
        custom-input-class="font-mono"
      />
      <div
        v-if="showSaved"
        class="flex items-center justify-between gap-2 px-3 py-1.5 text-sm rounded-lg bg-n-alpha-1"
        data-test="auth-saved"
      >
        <span class="flex items-center gap-2 text-n-slate-11">
          <span class="i-lucide-lock size-3.5 text-n-teal-10" />
          {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.AUTH.SAVED') }}
        </span>
        <Button
          type="button"
          size="xs"
          variant="ghost"
          color="slate"
          :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.AUTH.REPLACE')"
          @click="isReplacing = true"
        />
      </div>
      <template v-else>
        <Input
          v-if="auth.type === 'bearer'"
          v-model="auth.token"
          type="password"
          :placeholder="t('CAPTAIN.CUSTOM_TOOLS.FORM.AUTH_CONFIG.BEARER_TOKEN')"
        />
        <Input
          v-if="auth.type === 'basic'"
          v-model="auth.password"
          type="password"
          :placeholder="t('CAPTAIN.CUSTOM_TOOLS.FORM.AUTH_CONFIG.PASSWORD')"
        />
        <Input
          v-if="auth.type === 'api_key'"
          v-model="auth.key"
          type="password"
          :placeholder="t('CAPTAIN.CUSTOM_TOOLS.ACTION.AUTH.KEY')"
        />
      </template>
    </div>
  </div>
</template>
