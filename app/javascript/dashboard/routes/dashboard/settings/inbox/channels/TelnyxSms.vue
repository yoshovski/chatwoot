<script setup>
import { reactive, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useVuelidate } from '@vuelidate/core';
import { required, requiredIf } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import { isPhoneE164 } from 'shared/helpers/Validators';
import { useStore, useMapGetter } from 'dashboard/composables/store';

import Input from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

// `voice` is set when this form is opened from the Voice channel page: the inbox is
// then created with calling on and also handles SMS through the messaging profile.
const props = defineProps({
  voice: { type: Boolean, default: false },
});

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const uiFlags = useMapGetter('inboxes/getUIFlags');

const state = reactive({
  inboxName: '',
  phoneNumber: '',
  apiKey: '',
  messagingProfileId: '',
  publicKey: '',
  accountSid: '',
  outboundVoiceProfileId: '',
});

const validationRules = {
  inboxName: { required: requiredIf(() => !props.voice) },
  phoneNumber: { required, isPhoneE164 },
  apiKey: { required },
  messagingProfileId: { required: requiredIf(() => !props.voice) },
  accountSid: { required: requiredIf(() => props.voice) },
};

const v$ = useVuelidate(validationRules, state);
const isSubmitDisabled = computed(() => v$.value.$invalid);

const errorFor = (field, message) => (v$.value[field]?.$error ? message : '');

const formErrors = computed(() => ({
  inboxName: errorFor(
    'inboxName',
    t('INBOX_MGMT.ADD.SMS.TELNYX.INBOX_NAME.ERROR')
  ),
  phoneNumber: errorFor(
    'phoneNumber',
    t('INBOX_MGMT.ADD.VOICE.PHONE_NUMBER.ERROR')
  ),
  apiKey: errorFor('apiKey', t('INBOX_MGMT.ADD.SMS.TELNYX.API_KEY.ERROR')),
  messagingProfileId: errorFor(
    'messagingProfileId',
    t('INBOX_MGMT.ADD.SMS.TELNYX.MESSAGING_PROFILE_ID.ERROR')
  ),
  accountSid: errorFor(
    'accountSid',
    t('INBOX_MGMT.ADD.SMS.TELNYX.ACCOUNT_SID.ERROR')
  ),
}));

const providerConfig = () => {
  const config = {
    api_key: state.apiKey.trim(),
    messaging_profile_id: state.messagingProfileId.trim(),
    public_key: state.publicKey.trim(),
  };
  if (props.voice) {
    config.account_sid = state.accountSid.trim();
    config.outbound_voice_profile_id = state.outboundVoiceProfileId.trim();
  }
  return config;
};

const createInbox = () => {
  if (props.voice) {
    return store.dispatch('inboxes/createVoiceChannel', {
      name: `Voice (${state.phoneNumber})`,
      voice: {
        phone_number: state.phoneNumber,
        provider: 'telnyx',
        provider_config: providerConfig(),
      },
    });
  }
  return store.dispatch('inboxes/createChannel', {
    name: state.inboxName.trim(),
    channel: {
      type: 'sms',
      provider: 'telnyx',
      phone_number: state.phoneNumber,
      provider_config: providerConfig(),
    },
  });
};

async function createChannel() {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  try {
    const inbox = await createInbox();
    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: inbox.id },
    });
  } catch (error) {
    useAlert(
      error.response?.data?.message || t('INBOX_MGMT.ADD.SMS.API.ERROR_MESSAGE')
    );
  }
}
</script>

<template>
  <form
    class="flex flex-col gap-4 flex-wrap mx-0"
    @submit.prevent="createChannel"
  >
    <Input
      v-if="!voice"
      v-model="state.inboxName"
      :label="t('INBOX_MGMT.ADD.SMS.TELNYX.INBOX_NAME.LABEL')"
      :placeholder="t('INBOX_MGMT.ADD.SMS.TELNYX.INBOX_NAME.PLACEHOLDER')"
      :message="formErrors.inboxName"
      :message-type="formErrors.inboxName ? 'error' : 'info'"
      @blur="v$.inboxName?.$touch"
    />

    <Input
      v-model="state.phoneNumber"
      :label="t('INBOX_MGMT.ADD.VOICE.PHONE_NUMBER.LABEL')"
      :placeholder="t('INBOX_MGMT.ADD.VOICE.PHONE_NUMBER.PLACEHOLDER')"
      :message="formErrors.phoneNumber"
      :message-type="formErrors.phoneNumber ? 'error' : 'info'"
      @blur="v$.phoneNumber?.$touch"
    />

    <Input
      v-model="state.apiKey"
      type="password"
      :label="t('INBOX_MGMT.ADD.SMS.TELNYX.API_KEY.LABEL')"
      :placeholder="t('INBOX_MGMT.ADD.SMS.TELNYX.API_KEY.PLACEHOLDER')"
      :message="formErrors.apiKey"
      :message-type="formErrors.apiKey ? 'error' : 'info'"
      @blur="v$.apiKey?.$touch"
    />

    <Input
      v-if="voice"
      v-model="state.accountSid"
      :label="t('INBOX_MGMT.ADD.SMS.TELNYX.ACCOUNT_SID.LABEL')"
      :placeholder="t('INBOX_MGMT.ADD.SMS.TELNYX.ACCOUNT_SID.PLACEHOLDER')"
      :message="
        formErrors.accountSid || t('INBOX_MGMT.ADD.SMS.TELNYX.ACCOUNT_SID.HELP')
      "
      :message-type="formErrors.accountSid ? 'error' : 'info'"
      @blur="v$.accountSid?.$touch"
    />

    <Input
      v-model="state.messagingProfileId"
      :label="t('INBOX_MGMT.ADD.SMS.TELNYX.MESSAGING_PROFILE_ID.LABEL')"
      :placeholder="
        t('INBOX_MGMT.ADD.SMS.TELNYX.MESSAGING_PROFILE_ID.PLACEHOLDER')
      "
      :message="
        formErrors.messagingProfileId ||
        t('INBOX_MGMT.ADD.SMS.TELNYX.MESSAGING_PROFILE_ID.HELP')
      "
      :message-type="formErrors.messagingProfileId ? 'error' : 'info'"
      @blur="v$.messagingProfileId?.$touch"
    />

    <Input
      v-if="voice"
      v-model="state.outboundVoiceProfileId"
      :label="t('INBOX_MGMT.ADD.SMS.TELNYX.OUTBOUND_VOICE_PROFILE_ID.LABEL')"
      :placeholder="
        t('INBOX_MGMT.ADD.SMS.TELNYX.OUTBOUND_VOICE_PROFILE_ID.PLACEHOLDER')
      "
      :message="t('INBOX_MGMT.ADD.SMS.TELNYX.OUTBOUND_VOICE_PROFILE_ID.HELP')"
    />

    <Input
      v-model="state.publicKey"
      :label="t('INBOX_MGMT.ADD.SMS.TELNYX.PUBLIC_KEY.LABEL')"
      :placeholder="t('INBOX_MGMT.ADD.SMS.TELNYX.PUBLIC_KEY.PLACEHOLDER')"
      :message="t('INBOX_MGMT.ADD.SMS.TELNYX.PUBLIC_KEY.HELP')"
    />

    <div>
      <NextButton
        :is-loading="uiFlags.isCreating"
        :disabled="isSubmitDisabled"
        :label="
          voice
            ? t('INBOX_MGMT.ADD.VOICE.SUBMIT_BUTTON')
            : t('INBOX_MGMT.ADD.SMS.TELNYX.SUBMIT_BUTTON')
        "
        type="submit"
      />
    </div>
  </form>
</template>
