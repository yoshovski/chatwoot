<script setup>
import { ref, computed } from 'vue';
import CustomViewsAPI from 'dashboard/api/customViews';
import { useCamelCase } from 'dashboard/composables/useTransformKeys';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useContactFilterContext } from 'dashboard/components-next/filter/contactProvider';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import filterQueryGenerator from 'dashboard/helper/filterQueryGenerator';
import ConditionRow from 'dashboard/components-next/filter/ConditionRow.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['saved']);
const { t } = useI18n();
const store = useStore();
const { attributeFilterTypes, filterTypes } = useContactFilterContext();
const dialog = ref(null);
const rows = ref([]);
const conditions = ref([]);
const name = ref('');
const saving = ref(false);
const loading = ref(false);
const editingId = ref(null);
const title = computed(() =>
  editingId.value ? t('CUSTOMERS.EDIT_SEGMENT') : t('CUSTOMERS.NEW_SEGMENT')
);
const error = ref('');
const defaultCondition = () => ({
  attributeKey: 'email',
  filterOperator: 'contains',
  values: '@',
  queryOperator: 'and',
  attributeModel: 'standard',
});
const hydrate = filter => {
  const row = useCamelCase(filter);
  const type = filterTypes.value.find(
    item => item.attributeKey === row.attributeKey
  );
  const option = value =>
    type?.options?.find(item => item.id === value) || {
      id: value,
      name: String(value),
    };
  if (type?.inputType === 'multiSelect') row.values = row.values.map(option);
  else if (['searchSelect', 'booleanSelect'].includes(type?.inputType))
    row.values = option(row.values[0]);
  else row.values = row.values[0] ?? '';
  row.queryOperator ||= 'and';
  return row;
};
const open = async (segment = null) => {
  editingId.value = segment?.id ? Number(segment.id.split(':')[1]) : null;
  name.value = segment?.name || '';
  rows.value = [defaultCondition()];
  error.value = '';
  dialog.value.open();
  if (!editingId.value) return;
  loading.value = true;
  try {
    const { data } = await CustomViewsAPI.show(editingId.value);
    rows.value = data.query.payload.map(hydrate);
  } catch {
    error.value = t('CUSTOMERS.SAVE_ERROR');
    rows.value = [];
  } finally {
    loading.value = false;
  }
};
const save = async () => {
  if (
    !name.value.trim() ||
    !conditions.value.map(row => row.validate()).every(Boolean)
  )
    return;
  saving.value = true;
  error.value = '';
  try {
    const payload = {
      name: name.value.trim(),
      filter_type: 1,
      query: filterQueryGenerator(useSnakeCase(rows.value)),
    };
    let id = editingId.value;
    if (id) await store.dispatch('customViews/update', { ...payload, id });
    else id = (await store.dispatch('customViews/create', payload)).data.id;
    dialog.value.close();
    emit('saved', id);
  } catch {
    error.value = t('CUSTOMERS.SAVE_ERROR');
  } finally {
    saving.value = false;
  }
};
defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    width="3xl"
    :title="title"
    :confirm-button-label="
      editingId ? t('CUSTOMERS.SAVE_SEGMENT') : t('CUSTOMERS.CREATE_SEGMENT')
    "
    :is-loading="saving"
    :disable-confirm-button="saving || loading || !rows.length || !name.trim()"
    @confirm="save"
  >
    <div class="flex flex-col gap-5">
      <Input
        v-model="name"
        :label="t('CUSTOMERS.SEGMENT_NAME')"
        :placeholder="t('CUSTOMERS.SEGMENT_PLACEHOLDER')"
      />
      <div v-for="(row, index) in rows" :key="index" class="min-w-0">
        <ConditionRow
          ref="conditions"
          v-model:attribute-key="row.attributeKey"
          v-model:filter-operator="row.filterOperator"
          v-model:values="row.values"
          v-model:query-operator="rows[Math.max(0, index - 1)].queryOperator"
          :show-query-operator="index > 0"
          :filter-types="attributeFilterTypes"
          @remove="rows.length > 1 && rows.splice(index, 1)"
        />
      </div>
      <Button
        class="self-start"
        color="slate"
        variant="ghost"
        icon="i-lucide-plus"
        :label="t('CUSTOMERS.ADD_CONDITION')"
        @click="rows.push(defaultCondition())"
      />
      <p v-if="error" role="alert" class="m-0 text-sm text-n-ruby-11">
        {{ error }}
      </p>
    </div>
  </Dialog>
</template>
