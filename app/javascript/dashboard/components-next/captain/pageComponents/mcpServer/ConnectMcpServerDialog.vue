<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

// Two steps: connect (the server lists its tools), then choose the tools the AI agent may use.
// A failed connection stays on step one with the reason; trying again updates the saved server.
const props = defineProps({
  server: { type: Object, default: null },
  save: { type: Function, required: true },
  setEnabledTools: { type: Function, required: true },
});

const emit = defineEmits(['close']);

const { t } = useI18n();

const AUTH_TYPES = ['none', 'bearer', 'header'];
const STEPS = ['CONNECT', 'TOOLS'];

const dialogRef = ref(null);
const step = ref(0);
const isSaving = ref(false);
const saved = ref(props.server);
const enabledNames = ref([]);

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
const canConnect = computed(
  () =>
    state.name.trim() &&
    state.endpointUrl.trim().startsWith('https://') &&
    (state.authType !== 'header' || state.authHeaderName.trim()) &&
    (!needsToken.value || state.authToken.trim() || saved.value?.has_auth_token)
);

const connect = async () => {
  isSaving.value = true;
  try {
    saved.value = await props.save(saved.value?.id, {
      name: state.name.trim(),
      endpoint_url: state.endpointUrl.trim(),
      auth_type: state.authType,
      auth_header_name:
        state.authType === 'header' ? state.authHeaderName.trim() : null,
      auth_token: needsToken.value ? state.authToken.trim() : '',
    });
    if (saved.value.status !== 'connected') return;

    enabledNames.value = saved.value.tools
      .filter(tool => tool.enabled)
      .map(tool => tool.name);
    step.value = 1;
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('CAPTAIN.MCP_SERVERS.ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const toggleTool = (name, enabled) => {
  enabledNames.value = enabled
    ? [...enabledNames.value, name]
    : enabledNames.value.filter(item => item !== name);
};

const saveTools = async () => {
  isSaving.value = true;
  try {
    await props.setEnabledTools(saved.value.id, enabledNames.value);
    useAlert(t('CAPTAIN.MCP_SERVERS.CONNECT.SUCCESS'));
    dialogRef.value.close();
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('CAPTAIN.MCP_SERVERS.ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const confirm = () => (step.value === 0 ? connect() : saveTools());

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="2xl"
    :title="
      server
        ? t('CAPTAIN.MCP_SERVERS.CONNECT.EDIT_TITLE')
        : t('CAPTAIN.MCP_SERVERS.CONNECT.TITLE')
    "
    :description="
      step === 0
        ? t('CAPTAIN.MCP_SERVERS.CONNECT.DESCRIPTION')
        : t('CAPTAIN.MCP_SERVERS.CONNECT.TOOLS_DESCRIPTION', {
            name: saved?.name,
          })
    "
    :confirm-button-label="
      step === 0
        ? t('CAPTAIN.MCP_SERVERS.CONNECT.CONNECT_BUTTON')
        : t('CAPTAIN.MCP_SERVERS.CONNECT.SAVE_BUTTON')
    "
    :cancel-button-label="
      step === 0
        ? t('CAPTAIN.MCP_SERVERS.FORM.CANCEL')
        : t('CAPTAIN.MCP_SERVERS.CONNECT.LATER')
    "
    :is-loading="isSaving"
    :disable-confirm-button="step === 0 && !canConnect"
    @confirm="confirm"
    @close="emit('close')"
  >
    <ol class="flex items-center gap-2 p-0 m-0 text-xs font-medium list-none">
      <li
        v-for="(key, index) in STEPS"
        :key="key"
        class="flex items-center gap-2"
        :class="index === step ? 'text-n-slate-12' : 'text-n-slate-10'"
      >
        <span
          class="inline-flex items-center justify-center rounded-full size-5"
          :class="
            index <= step ? 'bg-n-brand text-white' : 'bg-n-alpha-2 text-n-slate-11'
          "
        >
          <i v-if="index < step" class="i-lucide-check size-3" />
          <template v-else>{{ index + 1 }}</template>
        </span>
        {{ t(`CAPTAIN.MCP_SERVERS.CONNECT.STEPS.${key}`) }}
        <span v-if="index < STEPS.length - 1" class="w-6 h-px bg-n-weak" />
      </li>
    </ol>

    <div v-if="step === 0" class="flex flex-col gap-4">
      <div class="grid gap-4 sm:grid-cols-2">
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
          :message="t('CAPTAIN.MCP_SERVERS.FORM.URL_HINT')"
        />
      </div>
      <div class="grid gap-4 sm:grid-cols-2">
        <div class="flex flex-col gap-1">
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
          saved?.has_auth_token
            ? t('CAPTAIN.MCP_SERVERS.FORM.TOKEN_KEEP')
            : t('CAPTAIN.MCP_SERVERS.FORM.TOKEN_PLACEHOLDER')
        "
      />
      <div
        v-if="saved?.status === 'failed'"
        class="flex items-start gap-2 px-3 py-2 text-sm rounded-lg bg-n-ruby-2 text-n-ruby-11"
        role="alert"
      >
        <i class="i-lucide-circle-alert size-4 mt-0.5 shrink-0" />
        <span>
          {{ t('CAPTAIN.MCP_SERVERS.CONNECT.FAILED') }}
          {{ saved.last_error }}
        </span>
      </div>
    </div>

    <div v-else class="flex flex-col gap-2">
      <p v-if="!saved.tools.length" class="m-0 text-sm text-n-slate-11">
        {{ t('CAPTAIN.MCP_SERVERS.NO_TOOLS') }}
      </p>
      <ul
        v-else
        class="flex flex-col p-0 m-0 overflow-y-auto divide-y max-h-80 divide-n-weak"
      >
        <li
          v-for="tool in saved.tools"
          :key="tool.name"
          class="flex items-start justify-between gap-4 py-3 list-none"
        >
          <div class="flex flex-col min-w-0 gap-0.5">
            <span class="text-sm font-medium text-n-slate-12">
              {{ tool.title }}
            </span>
            <span
              v-if="tool.description"
              class="text-sm text-n-slate-11 line-clamp-2"
            >
              {{ tool.description }}
            </span>
          </div>
          <Switch
            :model-value="enabledNames.includes(tool.name)"
            :aria-label="tool.title"
            class="mt-1"
            @update:model-value="toggleTool(tool.name, $event)"
          />
        </li>
      </ul>
      <p class="m-0 text-xs text-n-slate-11">
        {{ t('CAPTAIN.MCP_SERVERS.SCENARIO_HINT') }}
      </p>
    </div>
  </Dialog>
</template>
