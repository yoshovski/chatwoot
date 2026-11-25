<script setup>
import Draggable from 'vuedraggable';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import SettingsHelp from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsHelp.vue';

const fields = defineModel({ type: Array, required: true });

const moveField = (index, offset) => {
  const next = [...fields.value];
  const [field] = next.splice(index, 1);
  next.splice(index + offset, 0, field);
  fields.value = next;
};
</script>

<template>
  <Draggable
    v-model="fields"
    tag="ul"
    item-key="name"
    handle=".drag-handle"
    class="m-0 list-none divide-y divide-n-weak rounded-lg border border-n-weak p-0"
  >
    <template #item="{ element: field, index }">
      <li class="px-3 py-2.5 sm:px-4">
        <div class="flex min-w-0 items-center gap-1.5 sm:gap-2">
          <Icon
            icon="i-lucide-grip-vertical"
            class="drag-handle size-4 shrink-0 cursor-grab text-n-slate-10"
          />
          <span
            class="min-w-0 flex-1 break-words text-sm font-medium text-n-slate-12"
          >
            {{ field.label || field.name }}
          </span>
          <button
            type="button"
            class="grid size-8 shrink-0 place-items-center rounded-lg text-n-slate-11 hover:bg-n-alpha-1 disabled:opacity-35"
            :aria-label="
              $t('INBOX_MGMT.WEBSITE_SETTINGS.MOVE_UP', {
                field: field.label || field.name,
              })
            "
            :disabled="index === 0"
            @click="moveField(index, -1)"
          >
            <Icon icon="i-lucide-chevron-up" class="size-4" />
          </button>
          <button
            type="button"
            class="grid size-8 shrink-0 place-items-center rounded-lg text-n-slate-11 hover:bg-n-alpha-1 disabled:opacity-35"
            :aria-label="
              $t('INBOX_MGMT.WEBSITE_SETTINGS.MOVE_DOWN', {
                field: field.label || field.name,
              })
            "
            :disabled="index === fields.length - 1"
            @click="moveField(index, 1)"
          >
            <Icon icon="i-lucide-chevron-down" class="size-4" />
          </button>
          <ToggleSwitch
            v-model="field.enabled"
            :aria-label="
              $t('INBOX_MGMT.WEBSITE_SETTINGS.SHOW_FIELD', {
                field: field.label || field.name,
              })
            "
          />
        </div>
        <details v-if="field.enabled" class="mt-1 ps-6">
          <summary
            class="w-fit cursor-pointer rounded text-sm font-medium text-n-blue-11"
          >
            {{ $t('INBOX_MGMT.WEBSITE_SETTINGS.FIELD_OPTIONS') }}
          </summary>
          <div class="mt-3 flex flex-col gap-3">
            <div class="grid min-w-0 gap-3 sm:grid-cols-2">
              <label
                class="flex min-w-0 flex-col gap-1 text-sm font-medium text-n-slate-12"
              >
                {{ $t('INBOX_MGMT.PRE_CHAT_FORM.SET_FIELDS_HEADER.LABEL') }}
                <input
                  v-model="field.label"
                  type="text"
                  class="!m-0 min-h-10 w-full !rounded-lg"
                />
              </label>
              <label
                class="flex min-w-0 flex-col gap-1 text-sm font-medium text-n-slate-12"
              >
                {{
                  $t('INBOX_MGMT.PRE_CHAT_FORM.SET_FIELDS_HEADER.PLACE_HOLDER')
                }}
                <input
                  v-model="field.placeholder"
                  type="text"
                  class="!m-0 min-h-10 w-full !rounded-lg"
                />
              </label>
            </div>
            <div class="flex flex-wrap items-center justify-between gap-2">
              <label
                class="m-0 flex items-center gap-2 text-sm text-n-slate-12"
              >
                <input v-model="field.required" type="checkbox" class="m-0" />
                {{ $t('INBOX_MGMT.PRE_CHAT_FORM.SET_FIELDS_HEADER.REQUIRED') }}
              </label>
              <SettingsHelp
                :label="$t('INBOX_MGMT.WEBSITE_SETTINGS.FIELD_DETAILS')"
                :text="
                  $t('INBOX_MGMT.WEBSITE_SETTINGS.FIELD_METADATA', {
                    key: field.name,
                    type: field.type,
                  })
                "
              />
            </div>
          </div>
        </details>
      </li>
    </template>
  </Draggable>
</template>
