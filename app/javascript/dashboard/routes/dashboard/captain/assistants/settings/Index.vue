<script setup>
import { ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useAssistantSettings } from './useAssistantSettings';
import Button from 'dashboard/components-next/button/Button.vue';
import SettingsPageLayout from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsPageLayout.vue';
import AssistantBasicSettingsForm from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantBasicSettingsForm.vue';
import DeleteDialog from 'dashboard/components-next/captain/pageComponents/DeleteDialog.vue';
import KnowledgeBriefPanel from 'dashboard/components-next/captain/knowledge/KnowledgeBriefPanel.vue';

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
  <SettingsPageLayout :heading="t('PLATFORM_NAV.IDENTITY')">
    <AssistantBasicSettingsForm
      :assistant="assistant"
      :save="updateAssistant"
      @delete-avatar="deleteAssistantAvatar"
    >
      <template
        #default="{ description, descriptionMaxLength, setDescription }"
      >
        <KnowledgeBriefPanel
          v-if="assistantId"
          :key="`brief-${assistantId}`"
          :assistant-id="assistantId"
          :summary="description || ''"
          :summary-max-length="descriptionMaxLength"
          @use-overview="setDescription"
        />
        <div
          class="flex flex-wrap items-center justify-between gap-3 px-1 pt-2 text-xs text-n-slate-11"
        >
          <span class="min-w-0">
            {{
              t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.REMOVE_DESCRIPTION', {
                name: assistant.name,
              })
            }}
          </span>
          <Button
            :label="
              t('CAPTAIN.ASSISTANTS.SETTINGS.IDENTITY.REMOVE_TITLE', {
                name: assistant.name,
              })
            "
            color="ruby"
            variant="ghost"
            size="xs"
            icon="i-lucide-trash-2"
            @click="handleDelete"
          />
        </div>
      </template>
    </AssistantBasicSettingsForm>
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
