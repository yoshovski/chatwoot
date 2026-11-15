<script setup>
import { ref } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import ContactsAPI from 'dashboard/api/contacts';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import SidePanel from 'dashboard/components-next/side-panel/SidePanel.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { dynamicTime } from 'shared/helpers/timeHelper';

const { t } = useI18n();
const route = useRoute();
const panel = ref(null);
const customer = ref(null);
const conversations = ref([]);
const error = ref(false);
const { run, abort, isPending } = useAbortableRequest();
const open = async contact => {
  customer.value = contact;
  conversations.value = [];
  error.value = false;
  panel.value.open();
  try {
    const response = await run(signal =>
      ContactsAPI.getConversations(contact.id, { signal })
    );
    if (response) conversations.value = response.data.payload;
  } catch {
    error.value = true;
  }
};
defineExpose({ open });
</script>

<template>
  <SidePanel
    ref="panel"
    :title="t('CUSTOMERS.PROFILE')"
    width="lg"
    @close="abort"
  >
    <div v-if="customer" class="flex flex-col gap-5 p-5">
      <div class="flex items-center gap-3">
        <Avatar
          :name="customer.name || customer.email"
          :src="customer.thumbnail"
          :size="48"
          :status="customer.availability_status"
        />
        <div class="min-w-0">
          <h2 class="m-0 truncate text-lg font-semibold text-n-slate-12">
            {{ customer.name || t('CUSTOMERS.VISITOR', { id: customer.id }) }}
          </h2>
          <p class="m-0 truncate text-sm text-n-slate-11">
            {{ customer.email || customer.phone_number }}
          </p>
        </div>
      </div>
      <dl class="grid grid-cols-2 gap-3 text-sm">
        <dt class="text-n-slate-11">{{ t('CUSTOMERS.COLUMNS.LAST_SEEN') }}</dt>
        <dd class="m-0 text-end text-n-slate-12">
          {{
            customer.last_activity_at
              ? dynamicTime(customer.last_activity_at)
              : t('CUSTOMERS.UNKNOWN')
          }}
        </dd>
        <dt class="text-n-slate-11">
          {{ t('CUSTOMERS.COLUMNS.CONVERSATIONS') }}
        </dt>
        <dd class="m-0 text-end text-n-slate-12">
          {{ customer.conversations_count }}
        </dd>
      </dl>
      <div
        v-if="
          customer.availability_status === 'online' &&
          customer.website_activity?.current_page
        "
        class="rounded-xl bg-n-slate-2 p-3"
      >
        <h3 class="m-0 text-xs font-medium text-n-slate-11">
          {{ t('CUSTOMERS.COLUMNS.CURRENT_PAGE') }}
        </h3>
        <p class="mb-0 mt-2 break-all text-sm text-n-slate-12">
          {{
            customer.website_activity.current_page.title ||
            customer.website_activity.current_page.url
          }}
        </p>
        <p
          v-if="customer.website_activity.current_page.title"
          class="mb-0 mt-1 break-all text-xs text-n-slate-11"
        >
          {{ customer.website_activity.current_page.url }}
        </p>
      </div>
      <router-link
        :to="{
          name: 'contacts_edit',
          params: { accountId: route.params.accountId, contactId: customer.id },
        }"
      >
        <Button
          class="w-full"
          color="slate"
          variant="outline"
          :label="t('CUSTOMERS.FULL_PROFILE')"
          icon="i-lucide-arrow-up-right"
        />
      </router-link>
      <h3 class="m-0 text-sm font-semibold text-n-slate-12">
        {{ t('CUSTOMERS.RECENT_CONVERSATIONS') }}
      </h3>
      <Spinner v-if="isPending" />
      <p v-else-if="error" role="alert" class="text-sm text-n-ruby-11">
        {{ t('CUSTOMERS.LOAD_ERROR') }}
      </p>
      <p v-else-if="!conversations.length" class="text-sm text-n-slate-11">
        {{ t('CUSTOMERS.NO_CONVERSATIONS') }}
      </p>
      <template v-else>
        <router-link
          v-for="conversation in conversations.slice(0, 10)"
          :key="conversation.id"
          :to="`/app/accounts/${route.params.accountId}/conversations/${conversation.id}`"
          class="rounded-xl bg-n-slate-2 p-3 text-sm text-n-slate-12 hover:bg-n-slate-3"
        >
          <span class="font-medium">{{
            t('CUSTOMERS.CONVERSATION_ID', { id: conversation.id })
          }}</span>
          <p class="mb-0 mt-1 line-clamp-2 text-xs text-n-slate-11">
            {{
              conversation.last_non_activity_message?.content ||
              conversation.messages?.[0]?.content
            }}
          </p>
        </router-link>
      </template>
    </div>
  </SidePanel>
</template>
