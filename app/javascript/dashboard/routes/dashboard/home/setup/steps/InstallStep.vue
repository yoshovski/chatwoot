<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import StepIntro from './StepIntro.vue';

const props = defineProps({
  guided: { type: Object, required: true },
});

defineEmits(['open']);

const RESULT_STYLE = {
  installed: {
    icon: 'i-lucide-circle-check',
    tone: 'text-n-teal-10',
    text: 'HOME.GUIDED.INSTALL.RESULT.INSTALLED',
  },
  script_found: {
    icon: 'i-lucide-clock',
    tone: 'text-n-amber-10',
    text: 'HOME.GUIDED.INSTALL.RESULT.SCRIPT_FOUND',
  },
  not_found: {
    icon: 'i-lucide-circle-alert',
    tone: 'text-n-amber-10',
    text: 'HOME.GUIDED.INSTALL.RESULT.NOT_FOUND',
  },
  unreachable: {
    icon: 'i-lucide-circle-x',
    tone: 'text-n-ruby-10',
    text: 'HOME.GUIDED.INSTALL.RESULT.UNREACHABLE',
  },
  error: {
    icon: 'i-lucide-circle-x',
    tone: 'text-n-ruby-10',
    text: 'HOME.GUIDED.INSTALL.RESULT.ERROR',
  },
};

const { t } = useI18n();
const isChecking = ref(false);
const result = ref(props.guided.setup?.chat_widget ? 'installed' : '');

const inbox = computed(() => props.guided.state?.widget_inbox);
// The server's script is indented for an ERB template; drop the shared indent so it pastes cleanly.
const dedent = text => {
  const lines = text.replace(/^\n+|\s+$/g, '').split('\n');
  const indents = lines
    .filter(line => line.trim())
    .map(line => line.match(/^\s*/)[0].length);
  const shared = Math.min(...indents);
  return lines.map(line => line.slice(shared)).join('\n');
};
const snippet = computed(() => dedent(inbox.value?.web_widget_script || ''));
const site = computed(() => {
  try {
    return new URL(inbox.value.website_url).host.replace(/^www\./, '');
  } catch {
    return inbox.value?.website_url || '';
  }
});
const resultText = computed(() =>
  t(RESULT_STYLE[result.value].text, { site: site.value })
);

const copy = async () => {
  await copyTextToClipboard(snippet.value);
  useAlert(t('HOME.GUIDED.INSTALL.COPIED'));
};

const check = async () => {
  isChecking.value = true;
  try {
    result.value = await props.guided.checkInstallation();
  } catch {
    result.value = 'error';
  } finally {
    isChecking.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <StepIntro
      :title="$t('HOME.GUIDED.INSTALL.TITLE')"
      :description="inbox ? $t('HOME.GUIDED.INSTALL.DESCRIPTION') : ''"
    />

    <div
      v-if="!inbox"
      class="flex flex-col items-center gap-3 rounded-lg bg-n-alpha-1 px-4 py-10 text-center"
    >
      <Icon icon="i-lucide-code-xml" class="size-5 text-n-slate-10" />
      <p class="mb-0 max-w-sm text-sm text-n-slate-11">
        {{ $t('HOME.GUIDED.INSTALL.NO_INBOX') }}
      </p>
      <Button
        :label="$t('HOME.SETUP.STEPS.AGENT_INBOX.TITLE')"
        size="sm"
        variant="faded"
        color="slate"
        @click="$emit('open', 'agent_inbox')"
      />
    </div>

    <template v-else>
      <div class="relative min-w-0">
        <pre
          class="mb-0 max-h-56 overflow-auto rounded-lg bg-n-alpha-1 p-4 pe-28 text-xs leading-relaxed text-n-slate-12"
        ><code>{{ snippet }}</code></pre>
        <Button
          class="absolute end-2 top-2"
          :label="$t('HOME.GUIDED.INSTALL.COPY')"
          icon="i-lucide-copy"
          size="xs"
          variant="faded"
          color="slate"
          @click="copy"
        />
      </div>

      <div class="flex flex-col gap-3">
        <div class="flex flex-wrap items-center gap-2">
          <Button
            :label="$t('HOME.GUIDED.INSTALL.CHECK')"
            icon="i-lucide-radar"
            size="sm"
            :is-loading="isChecking"
            @click="check"
          />
          <router-link
            :to="{
              name: 'settings_inbox_show',
              params: { inboxId: inbox.id },
            }"
          >
            <Button
              :label="$t('HOME.GUIDED.INSTALL.SETTINGS')"
              size="sm"
              variant="ghost"
              color="slate"
            />
          </router-link>
        </div>
        <p
          v-if="result && !isChecking"
          role="status"
          class="mb-0 flex items-start gap-2 text-sm text-n-slate-11"
        >
          <Icon
            :icon="RESULT_STYLE[result].icon"
            class="mt-0.5 size-4 shrink-0"
            :class="RESULT_STYLE[result].tone"
          />
          {{ resultText }}
        </p>
      </div>
    </template>
  </div>
</template>
