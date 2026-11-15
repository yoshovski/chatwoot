<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { dynamicTime } from 'shared/helpers/timeHelper';

const props = defineProps({
  contacts: { type: Array, default: () => [] },
  columns: { type: Array, default: () => [] },
  selectedIds: { type: Array, default: () => [] },
  sort: { type: String, default: '-last_activity_at' },
  online: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
});
const emit = defineEmits(['select', 'selectAll', 'open', 'sort']);
const { t } = useI18n();
// Column keys come from the fixed translation mapping below.
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys */
const allSelected = computed(
  () =>
    props.contacts.length > 0 &&
    props.contacts.every(contact => props.selectedIds.includes(contact.id))
);
const someSelected = computed(() =>
  props.contacts.some(contact => props.selectedIds.includes(contact.id))
);
const columnKeys = {
  email: 'CUSTOMERS.COLUMNS.EMAIL',
  last_activity_at: 'CUSTOMERS.COLUMNS.LAST_SEEN',
  conversations_count: 'CUSTOMERS.COLUMNS.CONVERSATIONS',
  labels: 'CUSTOMERS.COLUMNS.LABELS',
  source: 'CUSTOMERS.COLUMNS.SOURCE',
};
const translatedColumns = computed(() =>
  Object.fromEntries(
    Object.entries(columnKeys).map(([key, value]) => [key, t(value)])
  )
);
const sortable = ['email', 'last_activity_at', 'conversations_count'];
const source = contact =>
  contact.website_activity?.arrival?.utm_source ||
  contact.website_activity?.arrival?.referrer_host ||
  '';
const currentPage = contact =>
  contact.availability_status === 'online'
    ? contact.website_activity?.current_page
    : null;
</script>

<template>
  <div class="overflow-x-auto">
    <table class="w-full border-collapse text-start text-sm">
      <thead>
        <tr class="border-b border-n-weak text-xs text-n-slate-11">
          <th scope="col" class="w-10 px-3 py-3">
            <input
              type="checkbox"
              class="m-0"
              :aria-label="t('CUSTOMERS.SELECT_PAGE')"
              :checked="allSelected"
              :indeterminate.prop="someSelected && !allSelected"
              :disabled="disabled"
              @change="emit('selectAll', $event.target.checked)"
            />
          </th>
          <th scope="col" class="min-w-44 py-3 pe-4 text-start font-medium">
            <button
              type="button"
              class="inline-flex items-center gap-1"
              @click="emit('sort', 'name')"
            >
              {{ t('CUSTOMERS.COLUMNS.NAME')
              }}<Icon
                :icon="
                  sort === 'name'
                    ? 'i-lucide-arrow-up'
                    : sort === '-name'
                      ? 'i-lucide-arrow-down'
                      : 'i-lucide-chevrons-up-down'
                "
                class="size-3"
              />
            </button>
          </th>
          <th
            v-if="online"
            scope="col"
            class="px-3 py-3 text-start font-medium"
          >
            {{ t('CUSTOMERS.COLUMNS.CURRENT_PAGE') }}
          </th>
          <th
            v-for="column in columns"
            :key="column"
            scope="col"
            class="px-3 py-3 text-start font-medium whitespace-nowrap"
            :aria-sort="
              sort.replace('-', '') === column
                ? sort.startsWith('-')
                  ? 'descending'
                  : 'ascending'
                : undefined
            "
          >
            <button
              v-if="sortable.includes(column)"
              type="button"
              class="inline-flex items-center gap-1"
              @click="emit('sort', column)"
            >
              {{ t(columnKeys[column])
              }}<Icon
                :icon="
                  sort === column
                    ? 'i-lucide-arrow-up'
                    : sort === `-${column}`
                      ? 'i-lucide-arrow-down'
                      : 'i-lucide-chevrons-up-down'
                "
                class="size-3"
              />
            </button>
            <div v-else>{{ translatedColumns[column] }}</div>
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="contact in contacts"
          :key="contact.id"
          class="border-b border-n-weak last:border-0 hover:bg-n-alpha-1"
          :class="selectedIds.includes(contact.id) ? 'bg-n-blue-2' : ''"
        >
          <td class="px-3 py-2">
            <input
              type="checkbox"
              class="m-0"
              :aria-label="
                t('CUSTOMERS.SELECT_CUSTOMER', {
                  name: contact.name || contact.email || contact.id,
                })
              "
              :checked="selectedIds.includes(contact.id)"
              :disabled="disabled"
              @change="emit('select', contact.id, $event.target.checked)"
            />
          </td>
          <td class="py-2 pe-4">
            <button
              type="button"
              class="flex w-full items-center gap-2.5 text-start"
              @click="emit('open', contact)"
            >
              <Avatar
                :name="contact.name || contact.email || String(contact.id)"
                :src="contact.thumbnail"
                :size="32"
                :status="contact.availability_status"
              />
              <div class="min-w-0">
                <div
                  class="block max-w-64 truncate font-medium text-n-slate-12"
                >
                  {{
                    contact.name ||
                    contact.email ||
                    t('CUSTOMERS.VISITOR', { id: contact.id })
                  }}
                </div>
                <div class="block text-xs text-n-slate-10">
                  {{
                    contact.phone_number ||
                    t('CUSTOMERS.CUSTOMER_ID', { id: contact.id })
                  }}
                </div>
              </div>
            </button>
          </td>
          <td v-if="online" class="max-w-64 px-3 py-2 text-xs text-n-slate-11">
            <div
              v-if="currentPage(contact)"
              class="block truncate"
              :title="currentPage(contact).url"
            >
              {{ currentPage(contact).title || currentPage(contact).url }}
            </div>
            <div v-else>{{ t('CUSTOMERS.UNKNOWN') }}</div>
          </td>
          <td
            v-for="column in columns"
            :key="column"
            class="px-3 py-2 text-xs text-n-slate-11"
          >
            <div v-if="column === 'last_activity_at'" class="whitespace-nowrap">
              {{
                contact.last_activity_at
                  ? dynamicTime(contact.last_activity_at)
                  : t('CUSTOMERS.UNKNOWN')
              }}
            </div>
            <div
              v-else-if="column === 'labels'"
              class="flex max-w-56 flex-wrap gap-1"
            >
              <div
                v-for="label in contact.labels"
                :key="label"
                class="rounded-md bg-n-slate-3 px-1.5 py-0.5"
              >
                {{ label }}
              </div>
            </div>
            <div v-else-if="column === 'source'">
              {{ source(contact) || t('CUSTOMERS.UNKNOWN') }}
            </div>
            <div v-else class="block max-w-64 truncate">
              {{
                contact[column] ||
                (column === 'conversations_count' ? 0 : t('CUSTOMERS.UNKNOWN'))
              }}
            </div>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
