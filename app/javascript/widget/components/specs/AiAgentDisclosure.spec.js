import { mount } from '@vue/test-utils';
import AiAgentDisclosure from '../AiAgentDisclosure.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => `${key}:${params.name}`,
  }),
}));

describe('AiAgentDisclosure', () => {
  afterEach(() => {
    delete window.chatwootWebChannel;
  });

  it('tells the customer which AI agent answers', () => {
    window.chatwootWebChannel = { captainAssistant: { name: 'Luna' } };

    expect(mount(AiAgentDisclosure).text()).toBe('AI_AGENT_HEADER.LABEL:Luna');
  });

  it('renders nothing when the inbox has no AI agent', () => {
    window.chatwootWebChannel = { captainAssistant: null };

    expect(mount(AiAgentDisclosure).html()).toBe('<!--v-if-->');
  });
});
