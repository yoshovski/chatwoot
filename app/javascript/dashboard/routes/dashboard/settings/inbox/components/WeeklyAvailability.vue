<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useConfig } from 'dashboard/composables/useConfig';
import inboxMixin from 'shared/mixins/inboxMixin';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import BusinessDay from './BusinessDay.vue';
import WidgetSection from '../settingsPage/widget/WidgetSection.vue';
import ChannelFormActions from './ChannelFormActions.vue';
import {
  timeSlotParse,
  timeSlotTransform,
  defaultTimeSlot,
  timeZoneOptions,
} from '../helpers/businessHour';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const DEFAULT_TIMEZONE = {
  label: 'Pacific Time (US & Canada) (GMT-07:00)',
  value: 'America/Los_Angeles',
};

export default {
  components: {
    SettingsToggleSection,
    SettingsFieldSection,
    BusinessDay,
    WidgetSection,
    ChannelFormActions,
    NextButton,
    WootMessageEditor,
    ComboBox,
  },
  mixins: [inboxMixin],
  props: {
    website: { type: Boolean, default: false },
    inbox: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      isBusinessHoursEnabled: false,
      unavailableMessage: '',
      unavailableMessageTranslations: {},
      selectedLocale: '',
      timeZone: DEFAULT_TIMEZONE,
      dayNames: {
        0: 'Sunday',
        1: 'Monday',
        2: 'Tuesday',
        3: 'Wednesday',
        4: 'Thursday',
        5: 'Friday',
        6: 'Saturday',
      },
      timeSlots: [...defaultTimeSlot],
    };
  },
  computed: {
    savedSchedule() {
      return JSON.stringify([
        this.inbox.id,
        this.inbox.working_hours_enabled,
        this.inbox.out_of_office_message,
        this.inbox.out_of_office_message_translations,
        this.inbox.working_hours,
        this.inbox.timezone,
      ]);
    },
    ...mapGetters({ uiFlags: 'inboxes/getUIFlags' }),
    languageOptions() {
      const { enabledLanguages } = useConfig();
      return (enabledLanguages || []).map(
        ({ iso_639_1_code: value, name: label }) => ({ value, label })
      );
    },
    localizedMessage: {
      get() {
        return this.unavailableMessageTranslations[this.selectedLocale] || '';
      },
      set(value) {
        if (value.trim())
          this.unavailableMessageTranslations[this.selectedLocale] = value;
        else delete this.unavailableMessageTranslations[this.selectedLocale];
      },
    },
    hasError() {
      if (!this.isBusinessHoursEnabled) return false;
      return this.timeSlots.filter(slot => slot.from && !slot.valid).length > 0;
    },
    timeZones() {
      return [...timeZoneOptions()];
    },
    timeZoneValue: {
      get() {
        return this.timeZone.value;
      },
      set(value) {
        const match = this.timeZones.find(tz => tz.value === value);
        if (match) this.timeZone = match;
      },
    },
    isRichEditorEnabled() {
      if (
        this.isATwilioChannel ||
        this.isATwitterInbox ||
        this.isAFacebookInbox
      )
        return false;
      return true;
    },
  },
  watch: {
    savedSchedule() {
      this.setDefaults();
    },
  },
  mounted() {
    this.setDefaults();
  },
  methods: {
    setDefaults() {
      const {
        working_hours_enabled: isEnabled = false,
        out_of_office_message: unavailableMessage,
        out_of_office_message_translations: translations,
        working_hours: timeSlots = [],
        timezone: timeZone,
      } = this.inbox;
      const slots = timeSlotParse(timeSlots).length
        ? timeSlotParse(timeSlots)
        : defaultTimeSlot;
      this.isBusinessHoursEnabled = isEnabled;
      this.unavailableMessage = unavailableMessage || '';
      this.unavailableMessageTranslations = { ...translations };
      this.selectedLocale ||= this.languageOptions[0]?.value || '';
      this.timeSlots = slots;
      this.timeZone =
        this.timeZones.find(item => timeZone === item.value) ||
        DEFAULT_TIMEZONE;
    },
    onSlotUpdate(slotIndex, slotData) {
      this.timeSlots = this.timeSlots.map(item =>
        item.day === slotIndex ? slotData : item
      );
    },
    async updateInbox() {
      try {
        const payload = {
          id: this.inbox.id,
          formData: false,
          working_hours_enabled: this.isBusinessHoursEnabled,
          out_of_office_message: this.unavailableMessage,
          out_of_office_message_translations:
            this.unavailableMessageTranslations,
          working_hours: timeSlotTransform(this.timeSlots),
          timezone: this.timeZone.value,
          channel: {},
        };
        await this.$store.dispatch('inboxes/updateInbox', payload);
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(error.message || this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      }
    },
  },
};
</script>

<template>
  <form
    class="flex min-w-0 flex-col gap-4"
    :class="{ 'mx-6': !website }"
    @submit.prevent="updateInbox"
  >
    <WidgetSection>
      <SettingsToggleSection
        v-model="isBusinessHoursEnabled"
        inset
        :header="$t('INBOX_MGMT.BUSINESS_HOURS.TOGGLE_AVAILABILITY')"
        :description="$t('INBOX_MGMT.BUSINESS_HOURS.TOGGLE_HELP')"
      />
    </WidgetSection>
    <template v-if="isBusinessHoursEnabled">
      <WidgetSection :title="$t('INBOX_MGMT.BUSINESS_HOURS.WEEKLY_TITLE')">
        <SettingsFieldSection
          :stacked="website"
          :label="$t('INBOX_MGMT.BUSINESS_HOURS.TIMEZONE_LABEL')"
        >
          <ComboBox
            v-model="timeZoneValue"
            :options="timeZones"
            :placeholder="$t('INBOX_MGMT.BUSINESS_HOURS.DAY.CHOOSE')"
            :aria-label="$t('INBOX_MGMT.BUSINESS_HOURS.TIMEZONE_LABEL')"
          />
        </SettingsFieldSection>
        <ul
          class="m-0 list-none divide-y divide-n-weak rounded-xl border border-n-weak p-0"
        >
          <BusinessDay
            v-for="timeSlot in timeSlots"
            :key="timeSlot.day"
            :day-name="dayNames[timeSlot.day]"
            :time-slot="timeSlot"
            @update="data => onSlotUpdate(timeSlot.day, data)"
          />
        </ul>
      </WidgetSection>
      <WidgetSection :title="$t('INBOX_MGMT.WEBSITE_SETTINGS.OFFLINE_MESSAGE')">
        <div class="mb-4">
          <WootMessageEditor
            v-if="isRichEditorEnabled"
            v-model="unavailableMessage"
            enable-variables
            is-format-mode
            :placeholder="
              $t('INBOX_MGMT.BUSINESS_HOURS.UNAVAILABLE_MESSAGE_LABEL')
            "
            :min-height="4"
          />
          <textarea v-else v-model="unavailableMessage" type="text" />
        </div>
        <details v-if="languageOptions.length" class="mb-4">
          <summary class="cursor-pointer">
            {{ $t('INBOX_MGMT.BUSINESS_HOURS.TRANSLATIONS.TITLE') }}
          </summary>
          <div class="mt-2 flex flex-col gap-2">
            <ComboBox
              v-model="selectedLocale"
              :options="languageOptions"
              :aria-label="
                $t('INBOX_MGMT.BUSINESS_HOURS.TRANSLATIONS.LANGUAGE')
              "
            />
            <WootMessageEditor
              v-if="isRichEditorEnabled"
              v-model="localizedMessage"
              enable-variables
              is-format-mode
              :placeholder="
                $t('INBOX_MGMT.BUSINESS_HOURS.TRANSLATIONS.PLACEHOLDER')
              "
              :min-height="4"
            />
            <textarea
              v-else
              v-model="localizedMessage"
              :aria-label="$t('INBOX_MGMT.BUSINESS_HOURS.TRANSLATIONS.TITLE')"
              :placeholder="
                $t('INBOX_MGMT.BUSINESS_HOURS.TRANSLATIONS.PLACEHOLDER')
              "
            />
          </div>
        </details>
      </WidgetSection>
    </template>
    <ChannelFormActions>
      <NextButton
        type="submit"
        size="sm"
        :label="$t('INBOX_MGMT.BUSINESS_HOURS.UPDATE')"
        :is-loading="uiFlags.isUpdating"
        :disabled="hasError"
      />
    </ChannelFormActions>
  </form>
</template>

<style lang="scss" scoped>
:deep(.message-editor) {
  @apply border-0;
}

textarea {
  @apply min-h-[4rem] mt-1.5;
}
</style>
