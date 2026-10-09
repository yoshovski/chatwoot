import { mount } from '@vue/test-utils';
import AssistantBrandChip from './AssistantBrandChip.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

describe('AssistantBrandChip', () => {
  it('labels every assistant as an AI agent', () => {
    expect(mount(AssistantBrandChip).text()).toBe(
      'CAPTAIN.ASSISTANTS.AI_AGENT_CHIP'
    );
  });
});
