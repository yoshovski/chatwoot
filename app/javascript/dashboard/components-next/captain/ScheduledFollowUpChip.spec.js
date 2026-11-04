import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import en from 'dashboard/i18n/locale/en';
import ScheduledFollowUpChip from './ScheduledFollowUpChip.vue';
import CaptainConversationsAPI from 'dashboard/api/captain/conversations';

vi.mock('dashboard/api/captain/conversations', () => ({
  default: { getScheduledActions: vi.fn(), cancelScheduledAction: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const i18n = createI18n({ legacy: false, locale: 'en', messages: { en } });
const inTwoHours = Math.floor(Date.now() / 1000) + 2 * 60 * 60;

describe('ScheduledFollowUpChip', () => {
  beforeEach(() => {
    CaptainConversationsAPI.getScheduledActions.mockResolvedValue({
      data: {
        payload: [{ id: 7, kind: 'follow_up_message', due_at: inTwoHours }],
      },
    });
    CaptainConversationsAPI.cancelScheduledAction.mockResolvedValue({});
  });

  it('shows a pending follow-up with when it runs', async () => {
    const wrapper = mount(ScheduledFollowUpChip, {
      props: { conversationId: 12 },
      global: { plugins: [i18n] },
    });
    await flushPromises();

    expect(CaptainConversationsAPI.getScheduledActions).toHaveBeenCalledWith(
      12
    );
    expect(wrapper.find('[data-test="scheduled-follow-up"]').text()).toContain(
      'Follow-up scheduled · in about 2 hours'
    );
  });

  it('removes the chip after Cancel', async () => {
    const wrapper = mount(ScheduledFollowUpChip, {
      props: { conversationId: 12 },
      global: { plugins: [i18n] },
    });
    await flushPromises();

    await wrapper.find('button').trigger('click');
    await flushPromises();

    expect(CaptainConversationsAPI.cancelScheduledAction).toHaveBeenCalledWith(
      12,
      7
    );
    expect(wrapper.find('[data-test="scheduled-follow-up"]').exists()).toBe(
      false
    );
  });

  it('refetches when a new message arrives', async () => {
    const wrapper = mount(ScheduledFollowUpChip, {
      props: { conversationId: 12, lastMessageId: 1 },
      global: { plugins: [i18n] },
    });
    await flushPromises();
    CaptainConversationsAPI.getScheduledActions.mockResolvedValue({
      data: { payload: [] },
    });

    await wrapper.setProps({ lastMessageId: 2 });
    await flushPromises();

    expect(CaptainConversationsAPI.getScheduledActions).toHaveBeenCalledTimes(
      2
    );
    expect(wrapper.find('[data-test="scheduled-follow-up"]').exists()).toBe(
      false
    );
  });
});
