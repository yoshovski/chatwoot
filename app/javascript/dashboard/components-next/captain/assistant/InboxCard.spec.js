import { shallowMount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import Button from 'dashboard/components-next/button/Button.vue';
import InboxCard from './InboxCard.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/helper/inbox', () => ({
  INBOX_TYPES: {
    TWILIO: 'Channel::TwilioSms',
    WHATSAPP: 'Channel::Whatsapp',
    EMAIL: 'Channel::Email',
  },
  getInboxIconByType: () => 'i-lucide-globe',
}));

const mountComponent = (props = {}) =>
  shallowMount(InboxCard, {
    props: {
      id: 1,
      inbox: {
        id: 1,
        name: 'Acme Support',
        channel_type: 'Channel::WebWidget',
      },
      assistant: {
        id: 1,
        name: 'Octave',
        config: { response_window: 'always' },
      },
      ...props,
    },
    global: {
      stubs: {
        CardLayout: { template: '<div><slot /></div>' },
        Policy: { template: '<div><slot /></div>' },
      },
    },
  });

describe('InboxCard', () => {
  it('renders inbox name, channel type, active badge and schedule summary', () => {
    const wrapper = mountComponent();
    expect(wrapper.text()).toContain('Acme Support');
    expect(wrapper.text()).toContain('CAPTAIN.INBOXES.TYPES.WEB');
    expect(wrapper.text()).toContain('CAPTAIN.INBOXES.STATUS.ACTIVE');
    expect(wrapper.text()).toContain(
      'CAPTAIN.ASSISTANTS.FORM.SCHEDULE.ALWAYS.LABEL'
    );
  });

  it('emits action delete when disconnect button is clicked', async () => {
    const wrapper = mountComponent();
    const disconnectBtn = wrapper.findComponent(Button);
    expect(disconnectBtn.exists()).toBe(true);

    await disconnectBtn.vm.$emit('click');
    expect(wrapper.emitted('action')).toEqual([[{ action: 'delete', id: 1 }]]);
  });
});
