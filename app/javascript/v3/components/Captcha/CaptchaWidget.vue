<script setup>
// The captcha of the sign-up and resend-confirmation forms: Cloudflare Turnstile or hCaptcha, whichever the
// installation set up (CAPTCHA_PROVIDER). Both run invisibly until execute() and emit the token through `verify`.
import { ref, onMounted, onBeforeUnmount } from 'vue';
import VueHcaptcha from '@hcaptcha/vue3-hcaptcha';

const props = defineProps({
  provider: { type: String, required: true },
  siteKey: { type: String, required: true },
});

const emit = defineEmits(['verify', 'error']);

const TURNSTILE_SCRIPT =
  'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';

const hCaptcha = ref(null);
const turnstileContainer = ref(null);
let turnstileWidgetId = null;

const loadTurnstile = () =>
  new Promise((resolve, reject) => {
    if (window.turnstile) {
      resolve(window.turnstile);
      return;
    }
    const script = document.createElement('script');
    script.src = TURNSTILE_SCRIPT;
    script.async = true;
    script.onload = () => resolve(window.turnstile);
    script.onerror = reject;
    document.head.appendChild(script);
  });

onMounted(async () => {
  if (props.provider !== 'turnstile') return;
  try {
    const turnstile = await loadTurnstile();
    turnstileWidgetId = turnstile.render(turnstileContainer.value, {
      sitekey: props.siteKey,
      execution: 'execute',
      appearance: 'interaction-only',
      callback: token => emit('verify', token),
      'error-callback': () => emit('error'),
      'expired-callback': () => emit('error'),
      'timeout-callback': () => emit('error'),
    });
  } catch {
    emit('error');
  }
});

onBeforeUnmount(() => {
  if (turnstileWidgetId !== null) window.turnstile?.remove(turnstileWidgetId);
});

const execute = () => {
  if (props.provider === 'turnstile') {
    if (turnstileWidgetId === null) {
      emit('error');
      return;
    }
    window.turnstile.execute(turnstileWidgetId);
  } else {
    hCaptcha.value.execute();
  }
};

const reset = () => {
  if (props.provider === 'turnstile') {
    if (turnstileWidgetId !== null) window.turnstile.reset(turnstileWidgetId);
  } else {
    hCaptcha.value?.reset();
  }
};

defineExpose({ execute, reset });
</script>

<template>
  <div v-if="provider === 'turnstile'" ref="turnstileContainer" />
  <VueHcaptcha
    v-else
    ref="hCaptcha"
    size="invisible"
    :sitekey="siteKey"
    @verify="token => emit('verify', token)"
    @error="emit('error')"
    @expired="emit('error')"
    @challenge-expired="emit('error')"
    @closed="emit('error')"
  />
</template>
