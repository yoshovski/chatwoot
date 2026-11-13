<script setup>
import { computed, watch, onMounted, ref } from 'vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  useMapGetter,
  useFunctionGetter,
  useStore,
} from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import AccordionItem from 'dashboard/components/Accordion/AccordionItem.vue';
import ContactConversations from './ContactConversations.vue';
import ConversationAction from './ConversationAction.vue';
import ScheduledFollowUpChip from 'dashboard/components-next/captain/ScheduledFollowUpChip.vue';
import ConversationParticipant from './ConversationParticipant.vue';
import ContactInfo from './contact/ContactInfo.vue';
import ContactNotes from './contact/ContactNotes.vue';
import ConversationInfo from './ConversationInfo.vue';
import WebsiteActivity from './WebsiteActivity.vue';
import CustomAttributes from './customAttributes/CustomAttributes.vue';
import SharedFiles from './SharedFiles.vue';
import Draggable from 'vuedraggable';
import MacrosList from './Macros/List.vue';
import ShopifyOrdersList from 'dashboard/components/widgets/conversation/ShopifyOrdersList.vue';
import HubspotContactCard from 'dashboard/components/widgets/conversation/HubspotContactCard.vue';
import LinearIssuesList from 'dashboard/components/widgets/conversation/linear/IssuesList.vue';
import LinearSetupCTA from 'dashboard/components/widgets/conversation/linear/LinearSetupCTA.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  inboxId: {
    type: Number,
    default: undefined,
  },
});

const {
  uiSettings,
  updateUISettings,
  isContactSidebarItemOpen,
  conversationSidebarItemsOrder,
  isOnExpandedLayout,
} = useUISettings();

const dragging = ref(false);
const conversationSidebarItems = ref([]);

// Every section is a kit card in one movable list. Orders and previous conversations come
// first, and open, until the agent sets an order or closes them.
const FIRST_ITEMS = ['shopify_orders', 'previous_conversation'];
const OPEN_BY_DEFAULT = ['is_shopify_orders_open', 'is_previous_conv_open'];
const isSectionOpen = key => {
  if (OPEN_BY_DEFAULT.includes(key)) {
    return uiSettings.value[key] !== false;
  }
  return isContactSidebarItemOpen(key);
};
const toggleSection = key => {
  updateUISettings({ [key]: !isSectionOpen(key) });
};

const shopifyIntegration = useFunctionGetter(
  'integrations/getIntegration',
  'shopify'
);

const isShopifyFeatureEnabled = computed(() => {
  if (!shopifyIntegration.value?.enabled) return false;
  const hook = shopifyIntegration.value?.hooks?.[0];
  if (hook?.sat_managed) return false;
  return true;
});

const hubspotIntegration = useFunctionGetter(
  'integrations/getIntegration',
  'hubspot'
);

const isHubspotConnected = computed(
  () => !!hubspotIntegration.value?.hooks?.length
);

const { isCloudFeatureEnabled } = useAccount();

const isLinearFeatureEnabled = computed(() =>
  isCloudFeatureEnabled(FEATURE_FLAGS.LINEAR)
);

const linearIntegration = useFunctionGetter(
  'integrations/getIntegration',
  'linear'
);

const isLinearClientIdConfigured = computed(() => {
  return !!linearIntegration.value?.id;
});

const isLinearConnected = computed(
  () => linearIntegration.value?.enabled || false
);

const store = useStore();
const currentChat = useMapGetter('getSelectedChat');
// A new message can cancel the AI agent's scheduled follow-ups, so the chip refreshes on it.
const lastMessageId = computed(() => currentChat.value?.messages?.at(-1)?.id);
const conversationId = computed(() => props.conversationId);
const conversationMetadataGetter = useMapGetter(
  'conversationMetadata/getConversationMetadata'
);
const currentConversationMetaData = computed(() =>
  conversationMetadataGetter.value(conversationId.value)
);
const conversationAdditionalAttributes = computed(
  () => currentConversationMetaData.value.additional_attributes || {}
);

const channelType = computed(() => currentChat.value.meta?.channel);

const contactGetter = useMapGetter('contacts/getContact');
const contactId = computed(() => currentChat.value.meta?.sender?.id);
const contact = computed(() => contactGetter.value(contactId.value));
const contactAdditionalAttributes = computed(
  () => contact.value.additional_attributes || {}
);

const appliedContactFilter = useMapGetter('getAppliedContactFilter');

const isListScopedToContact = computed(
  () =>
    !isOnExpandedLayout.value &&
    appliedContactFilter.value?.id === contactId.value
);

const contactConversationsGetter = useMapGetter(
  'contactConversations/getContactConversation'
);
const hasPreviousConversations = computed(() =>
  contactConversationsGetter
    .value(contactId.value)
    .some(conversation => conversation.id !== Number(props.conversationId))
);
watch(
  contactId,
  id => {
    if (id) store.dispatch('contactConversations/get', id);
  },
  { immediate: true }
);

const getContactDetails = () => {
  if (contactId.value) {
    store.dispatch('contacts/show', { id: contactId.value });
  }
};

watch(contactId, (newContactId, prevContactId) => {
  if (newContactId && newContactId !== prevContactId) {
    getContactDetails();
  }
});

const onDragEnd = () => {
  dragging.value = false;
  updateUISettings({
    conversation_sidebar_items_order: conversationSidebarItems.value,
  });
};

const closeContactPanel = () => {
  updateUISettings({
    is_contact_sidebar_open: false,
    is_copilot_panel_open: false,
  });
};

onMounted(() => {
  conversationSidebarItems.value = conversationSidebarItemsOrder.value;
  if (!uiSettings.value.conversation_sidebar_items_order) {
    conversationSidebarItems.value = [
      ...FIRST_ITEMS.map(name => ({ name })),
      ...conversationSidebarItems.value.filter(
        item => !FIRST_ITEMS.includes(item.name)
      ),
    ];
  }
  getContactDetails();
  store.dispatch('attributes/get', 0);
  // Load integrations to ensure linear integration state is available
  store.dispatch('integrations/get', 'linear');
});
</script>

<template>
  <div class="w-full">
    <div class="flex flex-col gap-3 pb-3">
      <SectionCard :title="$t('CONVERSATION_SIDEBAR.PANEL.CUSTOMER')">
        <template #actions>
          <button
            type="button"
            class="text-n-slate-11 hover:text-n-slate-12"
            :aria-label="$t('CONVERSATION.SIDEBAR.CONTACT')"
            @click="closeContactPanel"
          >
            <Icon icon="i-lucide-x" class="size-4" />
          </button>
        </template>
        <ContactInfo
          :contact="contact"
          :channel-type="channelType"
          class="-mx-5 -mb-5 -mt-4"
        />
      </SectionCard>
    </div>
    <div class="pb-8 list-group">
      <Draggable
        :list="conversationSidebarItems"
        animation="200"
        ghost-class="ghost"
        handle=".drag-handle"
        item-key="name"
        class="flex flex-col gap-3"
        @start="dragging = true"
        @end="onDragEnd"
      >
        <template #item="{ element }">
          <div
            v-if="element.name === 'conversation_actions'"
            class="conversation--actions"
          >
            <AccordionItem
              card
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_ACTIONS')"
              :is-open="isSectionOpen('is_conv_actions_open')"
              @toggle="toggleSection('is_conv_actions_open')"
            >
              <ScheduledFollowUpChip
                :conversation-id="conversationId"
                :last-message-id="lastMessageId"
              />
              <ConversationAction
                :conversation-id="conversationId"
                :inbox-id="inboxId"
              />
            </AccordionItem>
          </div>
          <div
            v-else-if="element.name === 'conversation_participants'"
            class="conversation--actions"
          >
            <AccordionItem
              card
              :title="$t('CONVERSATION_PARTICIPANTS.SIDEBAR_TITLE')"
              :is-open="isSectionOpen('is_conv_participants_open')"
              @toggle="toggleSection('is_conv_participants_open')"
            >
              <ConversationParticipant
                :conversation-id="conversationId"
                :inbox-id="inboxId"
              />
            </AccordionItem>
          </div>
          <div v-else-if="element.name === 'conversation_info'">
            <AccordionItem
              card
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_INFO')"
              :is-open="isSectionOpen('is_conv_details_open')"
              compact
              @toggle="toggleSection('is_conv_details_open')"
            >
              <ConversationInfo
                :conversation-attributes="conversationAdditionalAttributes"
                :contact-attributes="contactAdditionalAttributes"
              />
              <WebsiteActivity
                v-if="channelType === 'Channel::WebWidget'"
                :conversation-id="conversationId"
              />
            </AccordionItem>
          </div>
          <div v-else-if="element.name === 'contact_attributes'">
            <AccordionItem
              card
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONTACT_ATTRIBUTES')"
              :is-open="isSectionOpen('is_contact_attributes_open')"
              compact
              @toggle="toggleSection('is_contact_attributes_open')"
            >
              <CustomAttributes
                attribute-type="contact_attribute"
                attribute-from="conversation_contact_panel"
                :contact-id="contact.id"
                :empty-state-message="
                  $t('CONVERSATION_CUSTOM_ATTRIBUTES.NO_RECORDS_FOUND')
                "
              />
            </AccordionItem>
          </div>
          <div
            v-else-if="
              element.name === 'previous_conversation' &&
              !isListScopedToContact &&
              hasPreviousConversations
            "
          >
            <AccordionItem
              v-if="contact.id"
              card
              :title="
                $t('CONVERSATION_SIDEBAR.ACCORDION.PREVIOUS_CONVERSATION')
              "
              :is-open="isSectionOpen('is_previous_conv_open')"
              compact
              @toggle="toggleSection('is_previous_conv_open')"
            >
              <ContactConversations
                :contact-id="contact.id"
                :conversation-id="conversationId"
              />
            </AccordionItem>
          </div>
          <woot-feature-toggle
            v-else-if="element.name === 'macros'"
            feature-key="macros"
          >
            <AccordionItem
              card
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.MACROS')"
              :is-open="isSectionOpen('is_macro_open')"
              compact
              @toggle="toggleSection('is_macro_open')"
            >
              <MacrosList :conversation-id="conversationId" />
            </AccordionItem>
          </woot-feature-toggle>
          <div
            v-else-if="
              element.name === 'linear_issues' &&
              isLinearFeatureEnabled &&
              isLinearClientIdConfigured
            "
          >
            <AccordionItem
              card
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.LINEAR_ISSUES')"
              :is-open="isSectionOpen('is_linear_issues_open')"
              compact
              @toggle="toggleSection('is_linear_issues_open')"
            >
              <LinearSetupCTA v-if="!isLinearConnected" />
              <LinearIssuesList v-else :conversation-id="conversationId" />
            </AccordionItem>
          </div>
          <div
            v-else-if="
              element.name === 'shopify_orders' && isShopifyFeatureEnabled
            "
          >
            <AccordionItem
              card
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.SHOPIFY_ORDERS')"
              :is-open="isSectionOpen('is_shopify_orders_open')"
              compact
              @toggle="toggleSection('is_shopify_orders_open')"
            >
              <ShopifyOrdersList :contact-id="contactId" />
            </AccordionItem>
          </div>
          <div
            v-else-if="
              element.name === 'hubspot_contact' &&
              isHubspotConnected &&
              contactId
            "
          >
            <AccordionItem
              card
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.HUBSPOT_CONTACT')"
              :is-open="isSectionOpen('is_hubspot_contact_open')"
              compact
              @toggle="toggleSection('is_hubspot_contact_open')"
            >
              <HubspotContactCard :contact-id="contactId" />
            </AccordionItem>
          </div>
          <div v-else-if="element.name === 'contact_notes'">
            <AccordionItem
              card
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONTACT_NOTES')"
              :is-open="isSectionOpen('is_contact_notes_open')"
              compact
              @toggle="toggleSection('is_contact_notes_open')"
            >
              <ContactNotes :contact-id="contactId" />
            </AccordionItem>
          </div>
          <div v-else-if="element.name === 'shared_files'">
            <AccordionItem
              card
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.SHARED_FILES')"
              :is-open="isSectionOpen('is_shared_files_open')"
              compact
              @toggle="toggleSection('is_shared_files_open')"
            >
              <SharedFiles />
            </AccordionItem>
          </div>
        </template>
      </Draggable>
    </div>
  </div>
</template>

<style lang="scss" scoped>
:deep(.contact--profile) {
  @apply pb-3 border-b border-solid border-n-weak;
}
</style>
