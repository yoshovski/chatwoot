<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  authType: {
    type: String,
    required: true,
    validator: value => ['none', 'bearer', 'basic', 'api_key'].includes(value),
  },
  // The saved secret is never sent back; the field shows "Saved" until the admin replaces it.
  configured: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();

const authConfig = defineModel('authConfig', {
  type: Object,
  default: () => ({}),
});

const isReplacing = ref(!props.configured);

watch(
  () => props.authType,
  () => {
    authConfig.value = {};
    isReplacing.value = true;
  }
);
</script>

<template>
  <div class="flex flex-col gap-2">
    <template v-if="authType === 'basic'">
      <Input
        v-model="authConfig.username"
        :label="t('CAPTAIN.CUSTOM_TOOLS.FORM.AUTH_CONFIG.USERNAME')"
        :placeholder="
          t('CAPTAIN.CUSTOM_TOOLS.FORM.AUTH_CONFIG.USERNAME_PLACEHOLDER')
        "
      />
    </template>
    <template v-else-if="authType === 'api_key'">
      <Input
        v-model="authConfig.name"
        :label="t('CAPTAIN.CUSTOM_TOOLS.FORM.AUTH_CONFIG.API_KEY')"
        :placeholder="
          t('CAPTAIN.CUSTOM_TOOLS.FORM.AUTH_CONFIG.API_KEY_PLACEHOLDER')
        "
      />
    </template>
    <div
      v-if="authType !== 'none' && !isReplacing"
      class="flex items-center justify-between gap-2 px-3 py-2 text-sm rounded-lg bg-n-alpha-1"
      data-test="auth-saved"
    >
      <span class="flex items-center gap-2 text-n-slate-12">
        <span class="i-lucide-lock size-4 text-n-teal-10" />
        {{ t('CAPTAIN.CUSTOM_TOOLS.ACTION.CONNECTION.SAVED') }}
      </span>
      <Button
        type="button"
        size="xs"
        variant="faded"
        color="slate"
        :label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.CONNECTION.REPLACE')"
        @click="isReplacing = true"
      />
    </div>
    <template v-else>
      <Input
        v-if="authType === 'bearer'"
        v-model="authConfig.token"
        type="password"
        :label="t('CAPTAIN.CUSTOM_TOOLS.FORM.AUTH_CONFIG.BEARER_TOKEN')"
        :placeholder="
          t('CAPTAIN.CUSTOM_TOOLS.FORM.AUTH_CONFIG.BEARER_TOKEN_PLACEHOLDER')
        "
      />
      <Input
        v-else-if="authType === 'basic'"
        v-model="authConfig.password"
        type="password"
        :label="t('CAPTAIN.CUSTOM_TOOLS.FORM.AUTH_CONFIG.PASSWORD')"
        :placeholder="
          t('CAPTAIN.CUSTOM_TOOLS.FORM.AUTH_CONFIG.PASSWORD_PLACEHOLDER')
        "
      />
      <Input
        v-else-if="authType === 'api_key'"
        v-model="authConfig.key"
        type="password"
        :label="t('CAPTAIN.CUSTOM_TOOLS.FORM.AUTH_CONFIG.API_VALUE')"
        :placeholder="
          t('CAPTAIN.CUSTOM_TOOLS.FORM.AUTH_CONFIG.API_VALUE_PLACEHOLDER')
        "
      />
    </template>
  </div>
</template>
