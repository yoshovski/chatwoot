import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import ConversationSidebar from '../ConversationSidebar.vue';

const mountSidebar = props =>
  mount(ConversationSidebar, {
    attachTo: document.body,
    props: { currentChat: { id: 1, inbox_id: 2 }, ...props },
    global: {
      mocks: { $t: key => key },
      stubs: { ContactPanel: true },
    },
  });

describe('ConversationSidebar', () => {
  it('docks beside the thread without a backdrop', () => {
    const wrapper = mountSidebar({ isDrawer: false });
    const panel = wrapper.find('[data-conversation-details]');
    expect(panel.attributes('role')).toBe('complementary');
    expect(wrapper.findAll('div.absolute.inset-0')).toHaveLength(0);
    wrapper.unmount();
  });

  it('as a drawer takes focus, closes on Escape and backdrop, and returns focus', async () => {
    const opener = document.createElement('button');
    document.body.appendChild(opener);
    opener.focus();

    const wrapper = mountSidebar({ isDrawer: true });
    await nextTick();
    const panel = wrapper.find('[data-conversation-details]');
    expect(panel.attributes('role')).toBe('dialog');
    expect(document.activeElement).toBe(panel.element);

    await panel.trigger('keydown', { key: 'Escape' });
    await wrapper.find('div.absolute.inset-0').trigger('click');
    expect(wrapper.emitted('close')).toHaveLength(2);

    wrapper.unmount();
    expect(document.activeElement).toBe(opener);
    opener.remove();
  });
});
