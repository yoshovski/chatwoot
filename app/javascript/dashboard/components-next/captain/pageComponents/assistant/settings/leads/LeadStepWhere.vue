<script setup>
import { computed, ref } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import LeadMoreOptions from './LeadMoreOptions.vue';
import { useLeadSettings } from './useLeadSettings';

// Step 3 · Where it goes: always the Leads list, optionally an email to a team and HubSpot.
// More options: HubSpot field mapping and transcripts.
const {
  label,
  settings,
  setup,
  teams,
  teamsError,
  notificationStatus,
  manageNotificationTeam,
  isHubspotConnected,
  openHubspotSettings,
  canManageIntegrations,
} = useLeadSettings();
const {
  hubspotState,
  transcriptState,
  requiredMappingKeys,
  unmappedKeys,
  businessLeadsOnly,
  loading,
} = setup;

const hubspotDialogRef = ref(null);
const hubspotLabel = computed(() =>
  label(`HUBSPOT.${hubspotState.value.toUpperCase()}`)
);
const transcriptLabel = computed(() =>
  label(`TRANSCRIPT.${transcriptState.value.toUpperCase()}`)
);
const ROW = 'flex flex-col gap-3 py-3.5 sm:flex-row sm:items-center';
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex flex-col divide-y divide-n-weak">
      <div :class="ROW" class="!pt-0">
        <span
          class="grid size-8 shrink-0 place-items-center rounded-lg bg-n-teal-3 text-n-teal-11"
        >
          <span class="i-lucide-inbox size-4" aria-hidden="true" />
        </span>
        <div class="flex min-w-0 flex-1 flex-col gap-0.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ label('SETUP.WHERE.LIST') }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ label('SETUP.WHERE.LIST_HELP') }}
          </span>
        </div>
        <span class="text-xs font-medium text-n-teal-11">
          {{ label('SETUP.WHERE.ALWAYS') }}
        </span>
      </div>

      <div :class="ROW">
        <span
          class="grid size-8 shrink-0 place-items-center rounded-lg bg-n-alpha-2 text-n-slate-11"
        >
          <span class="i-lucide-mail size-4" aria-hidden="true" />
        </span>
        <div class="flex min-w-0 flex-1 flex-col gap-0.5">
          <label
            for="lead-notification-team"
            class="text-sm font-medium text-n-slate-12"
          >
            {{ label('NOTIFICATION_TITLE') }}
          </label>
          <span
            class="text-xs"
            :class="
              notificationStatus === 'ready'
                ? 'text-n-teal-11'
                : ['off', 'save_to_check'].includes(notificationStatus)
                  ? 'text-n-slate-11'
                  : 'text-n-amber-11'
            "
            role="status"
          >
            {{
              label(`NOTIFICATION_STATUS.${notificationStatus.toUpperCase()}`)
            }}
            <Button
              v-if="
                canManageIntegrations &&
                (notificationStatus === 'empty_team' ||
                  (!teamsError && !teams.length))
              "
              type="button"
              variant="link"
              size="xs"
              :label="
                label(
                  notificationStatus === 'empty_team'
                    ? 'MANAGE_TEAM'
                    : 'CREATE_TEAM'
                )
              "
              @click="manageNotificationTeam"
            />
          </span>
        </div>
        <div class="relative w-full shrink-0 sm:w-48">
          <select
            id="lead-notification-team"
            v-model="settings.lead_notification_team_id"
            :disabled="teamsError"
            class="m-0 w-full appearance-none rounded-xl border border-n-weak bg-n-solid-1 bg-none py-2 pe-8 ps-3 text-sm text-n-slate-12"
          >
            <option :value="null">{{ label('NOTIFICATION_OFF') }}</option>
            <option v-for="team in teams" :key="team.id" :value="team.id">
              {{ team.name }}
            </option>
          </select>
          <span
            class="i-lucide-chevron-down pointer-events-none absolute end-2.5 top-2.5 size-4 text-n-slate-11"
            aria-hidden="true"
          />
        </div>
      </div>

      <div :class="ROW">
        <span
          class="grid size-8 shrink-0 place-items-center rounded-lg bg-n-alpha-2 text-n-slate-11"
        >
          <span class="i-lucide-share-2 size-4" aria-hidden="true" />
        </span>
        <div class="flex min-w-0 flex-1 flex-col gap-0.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ label('SETUP.WHERE.HUBSPOT') }}
          </span>
          <span class="text-xs text-n-slate-11" role="status">
            {{ hubspotLabel }}
          </span>
        </div>
        <Button
          v-if="canManageIntegrations"
          type="button"
          variant="faded"
          color="slate"
          size="sm"
          :label="
            label(isHubspotConnected ? 'HUBSPOT_ACTION' : 'SETUP.WHERE.CONNECT')
          "
          @click="openHubspotSettings"
        />
      </div>
    </div>

    <LeadMoreOptions v-if="isHubspotConnected">
      <button
        type="button"
        class="flex items-center justify-between gap-3 rounded-xl bg-n-alpha-1 px-3.5 py-2.5 text-start text-sm text-n-slate-12 hover:bg-n-alpha-2"
        @click="hubspotDialogRef?.open()"
      >
        {{ label('HUBSPOT_TITLE') }}
        <span
          v-if="unmappedKeys.length"
          class="rounded-full bg-n-amber-3 px-2 py-0.5 text-xs font-medium text-n-amber-11"
        >
          {{ label('UNMAPPED_COUNT', { count: unmappedKeys.length }) }}
        </span>
      </button>
    </LeadMoreOptions>

    <Dialog
      ref="hubspotDialogRef"
      width="md"
      :title="label('HUBSPOT_TITLE')"
      :show-confirm-button="false"
      :cancel-button-label="label('CLOSE')"
    >
      <div class="flex flex-col gap-4">
        <div class="flex flex-col gap-1 rounded-xl bg-n-alpha-1 p-3.5">
          <span class="text-xs font-semibold text-n-slate-12">
            {{ hubspotLabel }}
          </span>
          <p class="m-0 text-xs text-n-slate-11">{{ label('VERIFICATION') }}</p>
        </div>
        <div
          v-if="requiredMappingKeys.length"
          class="flex flex-col divide-y divide-n-weak rounded-xl bg-n-alpha-1 px-3.5"
        >
          <div
            v-for="key in requiredMappingKeys"
            :key="key"
            class="flex items-center justify-between py-2 text-xs"
          >
            <code class="font-mono text-n-slate-12">{{ key }}</code>
            <span
              class="font-medium"
              :class="
                unmappedKeys.includes(key)
                  ? 'text-n-amber-11'
                  : 'text-n-teal-11'
              "
            >
              {{
                label(
                  unmappedKeys.includes(key) ? 'FIELD_UNMAPPED' : 'FIELD_MAPPED'
                )
              }}
            </span>
          </div>
        </div>
        <div class="flex flex-col gap-1 rounded-xl bg-n-alpha-1 p-3.5">
          <span class="text-xs font-semibold text-n-slate-12">
            {{ label('TRANSCRIPT_TITLE') }}
          </span>
          <span class="text-xs text-n-slate-11">{{ transcriptLabel }}</span>
          <p class="mb-0 mt-1 text-xs text-n-slate-11">
            {{
              label(
                businessLeadsOnly ? 'TRANSCRIPT_LEADS_HELP' : 'TRANSCRIPT_HELP'
              )
            }}
          </p>
        </div>
        <Button
          type="button"
          variant="ghost"
          color="slate"
          size="xs"
          icon="i-lucide-refresh-cw"
          class="self-start"
          :label="label('REFRESH')"
          :is-loading="loading"
          @click="setup.refresh"
        />
      </div>
    </Dialog>
  </div>
</template>
