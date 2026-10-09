<script setup>
import { ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useAssistantSettings } from './useAssistantSettings';
import Button from 'dashboard/components-next/button/Button.vue';
import SettingsPageLayout from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsPageLayout.vue';
import AssistantBasicSettingsForm from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantBasicSettingsForm.vue';
import AssistantChatPreview from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantChatPreview.vue';
import DeleteDialog from 'dashboard/components-next/captain/pageComponents/DeleteDialog.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { assistantId, assistant, updateAssistant, deleteAssistantAvatar } =
  useAssistantSettings();

const deleteAssistantDialog = ref(null);
const assistants = useMapGetter('captainAssistants/getRecords');

const handleDelete = () => {
  deleteAssistantDialog.value.dialogRef.open();
};

const handleDeleteSuccess = () => {
  // Get remaining assistants after deletion
  const remainingAssistants = assistants.value.filter(
    a => a.id !== assistantId.value
  );

  if (remainingAssistants.length > 0) {
    // Navigate to the first available assistant's settings
    const nextAssistant = remainingAssistants[0];
    router.push({
      name: 'captain_assistants_settings_index',
      params: {
        accountId: route.params.accountId,
        assistantId: nextAssistant.id,
      },
    });
  } else {
    // No assistants left, redirect to create assistant page
    router.push({
      name: 'captain_assistants_create_index',
      params: { accountId: route.params.accountId },
    });
  }
};
</script>

<template>
  <SettingsPageLayout
    :heading="
      t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.TITLE', { name: assistant.name })
    "
    :description="
      t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.DESCRIPTION', {
        name: assistant.name,
      })
    "
  >
    <div class="flex flex-col gap-6 lg:flex-row lg:items-start">
      <AssistantBasicSettingsForm
        :assistant="assistant"
        class="flex-1 min-w-0"
        @submit="updateAssistant"
        @delete-avatar="deleteAssistantAvatar"
      />
      <AssistantChatPreview
        :name="assistant.name"
        :avatar-url="assistant.avatar_url"
        class="lg:w-72 shrink-0"
      />
    </div>
    <div
      class="flex flex-wrap items-center justify-between w-full gap-4 px-5 py-4 rounded-xl outline outline-1 outline-n-ruby-5 bg-n-solid-1"
    >
      <div class="flex flex-col gap-0.5">
        <span class="text-sm font-medium text-n-slate-12">
          {{
            t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.REMOVE_TITLE', {
              name: assistant.name,
            })
          }}
        </span>
        <span class="text-sm text-n-slate-11">
          {{
            t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.REMOVE_DESCRIPTION', {
              name: assistant.name,
            })
          }}
        </span>
      </div>
      <Button
        :label="
          t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.REMOVE_TITLE', {
            name: assistant.name,
          })
        "
        color="ruby"
        variant="faded"
        size="sm"
        @click="handleDelete"
      />
    </div>
    <DeleteDialog
      v-if="assistant"
      ref="deleteAssistantDialog"
      :entity="assistant"
      type="Assistants"
      translation-key="ASSISTANTS"
      @delete-success="handleDeleteSuccess"
    />
  </SettingsPageLayout>
</template>
