<script setup>
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useWebsiteChannelNavigation } from 'dashboard/composables/useWebsiteChannelNavigation';
import Breadcrumb from 'next/breadcrumb/Breadcrumb.vue';
import PageHeader from 'next/kit/PageHeader.vue';
import ChannelAgentConnection from 'next/Channels/ChannelAgentConnection.vue';
import ChannelDelete from 'next/Channels/ChannelDelete.vue';
import WidgetSettings from './settingsPage/widget/WidgetSettings.vue';
import CollaboratorsPage from './settingsPage/CollaboratorsPage.vue';
import WeeklyAvailability from './components/WeeklyAvailability.vue';
import CustomerSatisfactionPage from './settingsPage/CustomerSatisfactionPage.vue';
import PreChatFormSettings from './PreChatForm/Settings.vue';

const props = defineProps({ inbox: { type: Object, required: true } });

const { t } = useI18n();
const router = useRouter();
const store = useStore();

const { activePage, hasCaptain, navigation, routeFor } =
  useWebsiteChannelNavigation();
const breadcrumbs = computed(() => [
  { label: t('CHANNELS.TITLE'), to: { name: 'settings_inbox_list' } },
  { label: props.inbox.name, to: routeFor('appearance') },
  { label: activePage.value.label },
]);
const sectionNav = ref(null);
const sectionHeading = ref(null);
const visited = ref([]);
watch(
  () => activePage.value.name,
  (key, previous) => {
    if (!visited.value.includes(key)) visited.value.push(key);
    if (key === 'pre-chat-form') store.dispatch('attributes/get');
    if (key === 'collaborators') store.dispatch('agents/get');
    if (key === 'csat') store.dispatch('labels/get');
    if (
      previous &&
      (sectionNav.value?.contains(document.activeElement) ||
        document.activeElement?.closest('#co-section-panel'))
    ) {
      sectionHeading.value?.focus({ preventScroll: true });
      sectionHeading.value?.scrollIntoView({ block: 'nearest' });
    }
  },
  { immediate: true, flush: 'post' }
);

store.dispatch('portals/index');
</script>

<template>
  <div class="flex w-full min-w-0 flex-col gap-5">
    <Breadcrumb :items="breadcrumbs" @click="router.push($event.to)" />
    <div
      ref="sectionHeading"
      tabindex="-1"
      class="rounded-md focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-blue-9"
    >
      <PageHeader
        :title="activePage.label"
        :description="activePage.description"
      />
    </div>
    <nav
      ref="sectionNav"
      :aria-label="t('INBOX_MGMT.WEBSITE_SETTINGS.NAVIGATION')"
      class="xl:hidden"
    >
      <label
        class="flex min-w-0 max-w-md flex-col gap-1.5 text-sm font-medium text-n-slate-12"
      >
        {{ t('INBOX_MGMT.WEBSITE_SETTINGS.NAVIGATION') }}
        <select
          :value="activePage.name"
          class="!m-0 min-h-10 !rounded-lg !border-n-weak !bg-n-solid-1"
          @change="router.push(routeFor($event.target.value))"
        >
          <optgroup
            v-for="group in navigation"
            :key="group.name"
            :label="group.label"
          >
            <option
              v-for="link in group.children"
              :key="link.name"
              :value="link.name"
            >
              {{ link.label }}
            </option>
          </optgroup>
        </select>
      </label>
    </nav>
    <WidgetSettings
      :inbox="props.inbox"
      :section="activePage.name"
      :has-captain="hasCaptain"
      @open-installation="router.push(routeFor('installation'))"
      @open-appearance="router.push(routeFor('appearance'))"
    >
      <div
        v-if="visited.includes('collaborators')"
        v-show="activePage.name === 'collaborators'"
        class="max-w-3xl"
      >
        <CollaboratorsPage :inbox="props.inbox" website />
      </div>
      <div
        v-if="visited.includes('business-hours')"
        v-show="activePage.name === 'business-hours'"
        class="max-w-3xl"
      >
        <WeeklyAvailability :inbox="props.inbox" website />
      </div>
      <div
        v-if="visited.includes('csat')"
        v-show="activePage.name === 'csat'"
        class="max-w-3xl"
      >
        <CustomerSatisfactionPage :inbox="props.inbox" website />
      </div>
      <div
        v-if="visited.includes('pre-chat-form')"
        v-show="activePage.name === 'pre-chat-form'"
        class="max-w-3xl"
      >
        <PreChatFormSettings :inbox="props.inbox" />
      </div>
      <div
        v-if="hasCaptain && visited.includes('ai-agent')"
        v-show="activePage.name === 'ai-agent'"
        class="max-w-3xl"
      >
        <ChannelAgentConnection :inbox="props.inbox" website />
      </div>
      <template #danger>
        <ChannelDelete :inbox="props.inbox" />
      </template>
    </WidgetSettings>
  </div>
</template>
