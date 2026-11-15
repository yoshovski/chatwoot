<script setup>
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys -- Keys share a fixed namespace and come from the lead settings or status list. */
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import LeadStatusMenu from './LeadStatusMenu.vue';
import { HUBSPOT_STATES, capturedAgo } from './leadsView';

// One row per captured lead; open its conversation or update the lead in place.
defineProps({
  leads: { type: Array, required: true },
  agents: { type: Array, required: true },
  ownersUnavailable: { type: Boolean, default: false },
  savingIds: { type: Set, required: true },
});
const emit = defineEmits(['open', 'status', 'owner']);
const { t } = useI18n();

const HEAD =
  'px-4 py-2.5 text-start text-xs font-medium text-n-slate-11 whitespace-nowrap';
const CELL = 'block px-4 py-2 align-middle sm:table-cell sm:py-3';
</script>

<template>
  <div
    class="overflow-x-auto"
    role="region"
    :aria-label="t('LEADS.TITLE')"
    tabindex="0"
  >
    <table class="block w-full border-collapse sm:table sm:min-w-[56rem]">
      <thead class="hidden sm:table-header-group">
        <tr class="border-b border-n-weak">
          <th :class="HEAD">{{ t('LEADS.COLUMNS.NAME') }}</th>
          <th :class="HEAD">{{ t('LEADS.COLUMNS.WANTS') }}</th>
          <th :class="HEAD">{{ t('LEADS.COLUMNS.STATUS') }}</th>
          <th :class="HEAD">{{ t('LEADS.COLUMNS.OWNER') }}</th>
          <th :class="HEAD">{{ t('LEADS.COLUMNS.HUBSPOT') }}</th>
          <th :class="HEAD" class="!text-end">{{ t('LEADS.COLUMNS.DATE') }}</th>
        </tr>
      </thead>
      <tbody class="block sm:table-row-group">
        <tr
          v-for="lead in leads"
          :key="lead.id"
          class="grid cursor-pointer grid-cols-2 border-b border-n-weak py-3 last:border-0 hover:bg-n-alpha-1 sm:table-row sm:py-0"
          tabindex="0"
          @click="emit('open', lead)"
          @keydown.enter="emit('open', lead)"
        >
          <td :class="CELL" class="col-span-2">
            <div class="flex min-w-0 items-center gap-3">
              <Avatar :name="lead.name" :size="32" rounded-full />
              <div class="flex min-w-0 flex-col">
                <span class="truncate text-sm font-medium text-n-slate-12">
                  {{ lead.name }}
                </span>
                <span class="truncate text-xs text-n-slate-11">
                  {{ lead.email }}
                </span>
              </div>
            </div>
          </td>
          <td :class="CELL" class="col-span-2 sm:max-w-[20rem]">
            <p class="m-0 line-clamp-2 text-sm text-n-slate-12">
              {{ lead.wants }}
            </p>
            <span class="text-xs text-n-slate-11">
              {{ [lead.company, lead.type].filter(Boolean).join(' · ') }}
            </span>
          </td>
          <td :class="CELL">
            <span class="mb-1 block text-xs text-n-slate-11 sm:hidden">{{
              t('LEADS.COLUMNS.STATUS')
            }}</span>
            <LeadStatusMenu
              :status="lead.status"
              :disabled="savingIds.has(lead.id)"
              @change="emit('status', lead, $event)"
            />
          </td>
          <td :class="CELL">
            <span class="mb-1 block text-xs text-n-slate-11 sm:hidden">{{
              t('LEADS.COLUMNS.OWNER')
            }}</span>
            <select
              :key="`${lead.id}-${lead.owner?.id}-${savingIds.has(lead.id)}`"
              :value="lead.owner?.id ?? ''"
              :disabled="ownersUnavailable || savingIds.has(lead.id)"
              :aria-label="t('LEADS.OWNER_FOR', { name: lead.name })"
              class="m-0 w-32 rounded-lg border-n-weak bg-n-solid-2 py-1 pe-6 ps-2 text-xs text-n-slate-12"
              @click.stop
              @keydown.stop
              @change="
                emit(
                  'owner',
                  lead,
                  $event.target.value === ''
                    ? null
                    : Number($event.target.value)
                )
              "
            >
              <option value="">{{ t('LEADS.NO_OWNER') }}</option>
              <option v-for="agent in agents" :key="agent.id" :value="agent.id">
                {{ agent.name }}
              </option>
            </select>
          </td>
          <td :class="CELL">
            <span class="mb-1 block text-xs text-n-slate-11 sm:hidden">{{
              t('LEADS.COLUMNS.HUBSPOT')
            }}</span>
            <span
              class="flex items-center gap-1.5 whitespace-nowrap text-xs font-medium"
              :class="HUBSPOT_STATES[lead.hubspot].tone"
            >
              <span
                :class="HUBSPOT_STATES[lead.hubspot].icon"
                class="size-3.5"
                aria-hidden="true"
              />
              {{ t(`LEADS.HUBSPOT.${lead.hubspot.toUpperCase()}`) }}
            </span>
          </td>
          <td
            :class="CELL"
            class="whitespace-nowrap text-xs text-n-slate-11 sm:text-end"
          >
            <span class="mb-1 block text-xs text-n-slate-11 sm:hidden">{{
              t('LEADS.COLUMNS.DATE')
            }}</span>
            {{ capturedAgo(lead.captured_at) }}
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
