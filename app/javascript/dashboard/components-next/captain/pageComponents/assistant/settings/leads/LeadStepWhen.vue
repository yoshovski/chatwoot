<script setup>
import { ref } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import SettingsSwitchRow from '../SettingsSwitchRow.vue';
import LeadMoreOptions from './LeadMoreOptions.vue';
import { useLeadSettings } from './useLeadSettings';

// Step 2 · When to ask: who gets the offer. More options: notes, handoff capture, pricing, the scenario.
const {
  label,
  settings,
  setup,
  guidedSetup,
  isDirty,
  openScenarios,
  scenarioDialog,
} = useLeadSettings();
const { captureScenario, loading, scenarioError } = setup;

const guidedDialogRef = ref(null);
const adoptGuidedSetup = () => {
  settings.value.lead_guided_setup = true;
  guidedDialogRef.value?.close();
};

const TEXTAREA =
  'm-0 w-full resize-y rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-sm font-normal text-n-slate-12 placeholder:text-n-slate-10 focus:border-n-brand focus:outline-none';
</script>

<template>
  <div class="flex flex-col gap-4">
    <template v-if="guidedSetup">
      <label
        class="m-0 flex flex-col gap-1.5 text-sm font-medium text-n-slate-12"
      >
        {{ label('GUIDED.TRIGGER') }}
        <textarea
          v-model="settings.lead_trigger"
          rows="3"
          maxlength="500"
          :placeholder="label('GUIDED.DEFAULT_TRIGGER')"
          :class="TEXTAREA"
        />
      </label>
      <p class="m-0 text-xs text-n-slate-11">
        {{ label('CONVERSATION_HELP') }}
      </p>
    </template>
    <div
      v-else
      class="flex flex-wrap items-center justify-between gap-3 rounded-xl bg-n-alpha-1 px-3.5 py-3"
    >
      <p class="m-0 text-sm text-n-slate-11">
        {{ label('GUIDED.CUSTOM_HELP') }}
      </p>
      <Button
        type="button"
        size="sm"
        variant="faded"
        :label="label('GUIDED.SWITCH')"
        :disabled="loading || scenarioError"
        @click="guidedDialogRef?.open()"
      />
    </div>

    <LeadMoreOptions>
      <label
        v-if="guidedSetup"
        class="m-0 flex flex-col gap-1.5 text-sm font-medium text-n-slate-12"
      >
        {{ label('GUIDED.NOTES') }}
        <textarea
          v-model="settings.lead_instructions"
          rows="3"
          maxlength="2000"
          :placeholder="label('GUIDED.NOTES_PLACEHOLDER')"
          :class="TEXTAREA"
        />
      </label>
      <div class="flex flex-col divide-y divide-n-weak">
        <SettingsSwitchRow
          v-model="settings.lead_handoff_capture_enabled"
          :title="label('HANDOFF_TITLE')"
          :description="label('HANDOFF_HELP')"
        />
        <SettingsSwitchRow
          v-model="settings.published_pricing_enabled"
          :title="label('PRICING_TITLE')"
          :description="label('PRICING_HELP')"
        />
      </div>
      <div
        class="flex flex-wrap items-center justify-between gap-3 rounded-xl bg-n-alpha-1 px-3.5 py-2.5"
        role="status"
      >
        <span class="text-xs text-n-slate-12">
          {{
            label(
              captureScenario && !isDirty
                ? 'GUIDED.CONVERSATION_READY'
                : 'GUIDED.CONVERSATION_ON_SAVE'
            )
          }}
        </span>
        <div class="flex items-center gap-1">
          <Button
            v-if="captureScenario"
            type="button"
            size="xs"
            variant="ghost"
            :label="label('GUIDED.VIEW_CONVERSATION')"
            @click="openScenarios"
          />
          <Button
            type="button"
            size="xs"
            variant="ghost"
            color="slate"
            :label="label('SCENARIO_TITLE')"
            @click="scenarioDialog?.open()"
          />
        </div>
      </div>
    </LeadMoreOptions>

    <Dialog
      ref="guidedDialogRef"
      :title="label('GUIDED.SWITCH')"
      :confirm-button-label="label('GUIDED.SWITCH')"
      @confirm="adoptGuidedSetup"
    >
      <p class="m-0 text-sm text-n-slate-11">
        {{ label('GUIDED.SWITCH_HELP') }}
      </p>
    </Dialog>
  </div>
</template>
