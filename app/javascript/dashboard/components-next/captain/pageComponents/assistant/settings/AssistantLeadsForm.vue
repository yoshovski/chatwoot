<script setup>
import { computed, ref } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import SettingsSwitchRow from './SettingsSwitchRow.vue';
import SettingsSaveBar from './SettingsSaveBar.vue';
import SettingsSplit from './SettingsSplit.vue';
import LeadStepAsk from './leads/LeadStepAsk.vue';
import LeadStepWhen from './leads/LeadStepWhen.vue';
import LeadStepWhere from './leads/LeadStepWhere.vue';
import LeadWidgetPreview from './leads/LeadWidgetPreview.vue';
import { STEPS, createLeadSettings } from './leads/useLeadSettings';

// Lead setup in three steps: What to ask · When to ask · Where it goes, with the website chat preview.
const props = defineProps({
  assistant: { type: Object, required: true },
  save: { type: Function, required: true },
  canManageIntegrations: { type: Boolean, default: false },
});

const lead = createLeadSettings({
  assistant: computed(() => props.assistant),
  save: config => props.save(config),
  canManageIntegrations: computed(() => props.canManageIntegrations),
});
const {
  label,
  settings,
  saving,
  attempted,
  hasErrors,
  isDirty,
  reset,
  enableCapture,
  setup,
  statusLabel,
  statusTone,
  summaries,
  scenarioDialog,
  guidedSetup,
  openScenarios,
} = lead;
const { captureScenario, existingScenario, loading, scenarioError } = setup;

const STEP_COMPONENTS = {
  ask: LeadStepAsk,
  when: LeadStepWhen,
  where: LeadStepWhere,
};
const stepTitle = step => label(`SETUP.STEPS.${step.toUpperCase()}.TITLE`);
const stepHint = step => label(`SETUP.STEPS.${step.toUpperCase()}.HINT`);

const form = ref(null);
const activeStep = ref('ask');

const stepIndex = step => STEPS.indexOf(step);
const goTo = offset => {
  activeStep.value = STEPS[stepIndex(activeStep.value) + offset];
};

// Every validation error is in "What to ask": show it before focusing the invalid field.
const submit = async () => {
  if (hasErrors.value) {
    activeStep.value = 'ask';
  }
  return lead.save(form.value);
};

const PILL_TONES = {
  live: 'bg-n-teal-3 text-n-teal-11',
  attention: 'bg-n-amber-3 text-n-amber-11',
  paused: 'bg-n-alpha-2 text-n-slate-11',
};
const DOT_TONES = {
  live: 'bg-n-teal-9',
  attention: 'bg-n-amber-9',
  paused: 'bg-n-slate-9',
};
</script>

<template>
  <form ref="form" class="flex flex-col gap-6" @submit.prevent="submit">
    <fieldset
      :disabled="saving"
      class="m-0 flex min-w-0 flex-col gap-6 border-0 p-0"
    >
      <section
        class="flex flex-col gap-3 rounded-card bg-n-solid-2 px-5 py-3 shadow-card outline outline-1 -outline-offset-1 outline-n-container sm:flex-row sm:items-center sm:justify-between"
      >
        <SettingsSwitchRow
          class="flex-1 !py-1"
          :model-value="settings.leads_enabled"
          :title="label('ENABLE')"
          :description="label('ENABLE_DESCRIPTION')"
          @update:model-value="enableCapture"
        />
        <button
          type="button"
          class="flex shrink-0 items-center gap-2 self-start rounded-full px-3 py-1 text-sm font-medium sm:self-center"
          :class="PILL_TONES[statusTone]"
          @click="scenarioDialog?.open()"
        >
          <span
            class="size-2 rounded-full"
            :class="DOT_TONES[statusTone]"
            aria-hidden="true"
          />
          {{ statusLabel }}
        </button>
      </section>

      <SettingsSplit>
        <!-- A · Stepper: one step at a time, Back / Next. -->
        <section
          class="flex flex-col gap-5 rounded-card bg-n-solid-2 p-5 shadow-card outline outline-1 -outline-offset-1 outline-n-container transition-opacity"
          :class="{ 'opacity-70': !settings.leads_enabled }"
        >
          <ol
            class="m-0 grid list-none grid-cols-3 gap-2 p-0"
            :aria-label="label('SETUP.TITLE')"
          >
            <li v-for="(step, index) in STEPS" :key="step" class="min-w-0">
              <button
                type="button"
                class="flex w-full min-w-0 flex-col gap-1 rounded-xl border-t-[3px] px-1 pt-2.5 text-start"
                :class="
                  activeStep === step
                    ? 'border-n-brand'
                    : 'border-n-weak hover:border-n-strong'
                "
                :aria-current="activeStep === step ? 'step' : undefined"
                @click="activeStep = step"
              >
                <span
                  class="text-xs font-medium"
                  :class="
                    activeStep === step ? 'text-n-blue-11' : 'text-n-slate-11'
                  "
                >
                  {{ label('SETUP.STEP_N', { n: index + 1 }) }}
                </span>
                <span class="text-sm font-semibold text-n-slate-12">
                  {{ stepTitle(step) }}
                </span>
                <span
                  class="hidden truncate text-xs text-n-slate-11 sm:block"
                  :title="summaries[step]"
                >
                  {{ summaries[step] }}
                </span>
              </button>
            </li>
          </ol>

          <div class="flex flex-col gap-1">
            <h3
              class="m-0 font-display text-lg font-semibold tracking-display text-n-slate-12"
            >
              {{ stepTitle(activeStep) }}
            </h3>
            <p class="m-0 text-sm text-n-slate-11">
              {{ stepHint(activeStep) }}
            </p>
          </div>
          <KeepAlive>
            <component :is="STEP_COMPONENTS[activeStep]" />
          </KeepAlive>

          <div
            class="flex items-center justify-between gap-3 border-t border-n-weak pt-4"
          >
            <Button
              v-if="stepIndex(activeStep) > 0"
              type="button"
              variant="ghost"
              color="slate"
              size="sm"
              icon="i-lucide-arrow-left"
              :label="label('SETUP.BACK')"
              @click="goTo(-1)"
            />
            <span v-else />
            <Button
              v-if="stepIndex(activeStep) < STEPS.length - 1"
              type="button"
              variant="faded"
              size="sm"
              trailing-icon
              icon="i-lucide-arrow-right"
              :label="
                label('SETUP.NEXT', {
                  step: stepTitle(STEPS[stepIndex(activeStep) + 1]),
                })
              "
              @click="goTo(1)"
            />
          </div>
        </section>

        <template #preview>
          <LeadWidgetPreview :focus="activeStep" />
        </template>
      </SettingsSplit>
    </fieldset>

    <p
      v-if="attempted && hasErrors"
      class="m-0 text-sm text-n-ruby-11"
      role="alert"
    >
      {{ label('ERRORS.FORM') }}
    </p>

    <SettingsSaveBar
      :is-dirty="isDirty"
      :is-saving="saving"
      @save="submit"
      @discard="reset"
    />

    <Dialog
      :ref="el => (scenarioDialog = el)"
      width="lg"
      :title="label('SCENARIO_TITLE')"
      :show-confirm-button="false"
      :cancel-button-label="label('CLOSE')"
    >
      <div class="flex flex-col gap-4">
        <div class="flex flex-col gap-2 rounded-xl bg-n-alpha-1 p-3.5">
          <span class="text-xs font-medium text-n-slate-12">
            {{
              loading
                ? label('STATUS.CHECKING')
                : scenarioError
                  ? label('SCENARIO_ERROR')
                  : captureScenario
                    ? label('SCENARIO_FOUND', { name: captureScenario.title })
                    : existingScenario
                      ? label('SCENARIO_PAUSED', {
                          name: existingScenario.title,
                        })
                      : label('SCENARIO_MISSING')
            }}
          </span>
          <div class="flex flex-wrap items-center gap-2 pt-1">
            <Button
              type="button"
              size="xs"
              variant="faded"
              icon="i-lucide-git-branch"
              :disabled="!settings.leads_enabled || loading || scenarioError"
              :is-loading="saving"
              :label="
                label(
                  existingScenario
                    ? 'MANAGE_SCENARIO'
                    : isDirty
                      ? 'SAVE_ADD_SCENARIO'
                      : 'ADD_SCENARIO'
                )
              "
              @click="openScenarios"
            />
            <Button
              type="button"
              variant="ghost"
              color="slate"
              size="xs"
              icon="i-lucide-refresh-cw"
              :label="label('REFRESH')"
              :is-loading="loading"
              @click="setup.refresh"
            />
          </div>
        </div>
        <p class="m-0 text-xs text-n-slate-11">
          {{
            label(
              guidedSetup ? 'GUIDED.SETUP_EXPLANATION' : 'GUIDED.CUSTOM_HELP'
            )
          }}
        </p>
      </div>
    </Dialog>
  </form>
</template>
