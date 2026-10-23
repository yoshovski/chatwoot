<script setup>
import { computed, reactive } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Button from 'dashboard/components-next/button/Button.vue';

// Connection details for a new server, or for an existing one (its token is never sent back, so blank keeps it).
const props = defineProps({
  server: { type: Object, default: null },
  isSaving: { type: Boolean, default: false },
});

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

const AUTH_TYPES = ['none', 'bearer', 'header'];

const state = reactive({
  name: props.server?.name || '',
  endpointUrl: props.server?.endpoint_url || '',
  authType: props.server?.auth_type || 'none',
  authHeaderName: props.server?.auth_header_name || '',
  authToken: '',
});

const authOptions = computed(() =>
  AUTH_TYPES.map(type => ({
    value: type,
    label: t(`CAPTAIN.MCP_SERVERS.FORM.AUTH_TYPES.${type.toUpperCase()}`),
  }))
);

const needsToken = computed(() => state.authType !== 'none');
const canSubmit = computed(
  () =>
    state.name.trim() &&
    state.endpointUrl.trim().startsWith('https://') &&
    (state.authType !== 'header' || state.authHeaderName.trim()) &&
    (!needsToken.value ||
      state.authToken.trim() ||
      props.server?.has_auth_token)
);

const submit = () => {
  emit('submit', {
    name: state.name.trim(),
    endpoint_url: state.endpointUrl.trim(),
    auth_type: state.authType,
    auth_header_name:
      state.authType === 'header' ? state.authHeaderName.trim() : null,
    auth_token: needsToken.value ? state.authToken.trim() : '',
  });
};
</script>

<template>
  <form
    class="flex flex-col gap-3 p-4 rounded-xl bg-n-alpha-1 outline outline-1 outline-n-weak"
    @submit.prevent="submit"
  >
    <div class="grid gap-3 sm:grid-cols-2">
      <Input
        v-model="state.name"
        :label="t('CAPTAIN.MCP_SERVERS.FORM.NAME')"
        :placeholder="t('CAPTAIN.MCP_SERVERS.FORM.NAME_PLACEHOLDER')"
      />
      <Input
        v-model="state.endpointUrl"
        type="url"
        :label="t('CAPTAIN.MCP_SERVERS.FORM.URL')"
        :placeholder="t('CAPTAIN.MCP_SERVERS.FORM.URL_PLACEHOLDER')"
      />
    </div>
    <div class="grid gap-3 sm:grid-cols-2">
      <div class="flex flex-col gap-1.5">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CAPTAIN.MCP_SERVERS.FORM.AUTH') }}
        </span>
        <Select
          v-model="state.authType"
          :options="authOptions"
          :aria-label="t('CAPTAIN.MCP_SERVERS.FORM.AUTH')"
          class="w-full [&>select]:w-full"
        />
      </div>
      <Input
        v-if="state.authType === 'header'"
        v-model="state.authHeaderName"
        :label="t('CAPTAIN.MCP_SERVERS.FORM.HEADER_NAME')"
        :placeholder="t('CAPTAIN.MCP_SERVERS.FORM.HEADER_NAME_PLACEHOLDER')"
      />
    </div>
    <Input
      v-if="needsToken"
      v-model="state.authToken"
      type="password"
      :label="t('CAPTAIN.MCP_SERVERS.FORM.TOKEN')"
      :placeholder="
        server?.has_auth_token
          ? t('CAPTAIN.MCP_SERVERS.FORM.TOKEN_KEEP')
          : t('CAPTAIN.MCP_SERVERS.FORM.TOKEN_PLACEHOLDER')
      "
    />
    <div class="flex justify-end gap-2">
      <Button
        type="button"
        :label="t('CAPTAIN.MCP_SERVERS.FORM.CANCEL')"
        size="sm"
        variant="faded"
        color="slate"
        @click="emit('cancel')"
      />
      <Button
        type="submit"
        :label="t('CAPTAIN.MCP_SERVERS.FORM.CONNECT')"
        size="sm"
        :is-loading="isSaving"
        :disabled="!canSubmit || isSaving"
      />
    </div>
  </form>
</template>
