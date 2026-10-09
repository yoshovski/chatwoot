import { ref } from 'vue';
import { mount } from '@vue/test-utils';
import AssistantBrandChip from './AssistantBrandChip.vue';

const globalConfig = ref({ captainBrandName: 'Tony' });

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => globalConfig,
}));

const mountChip = name => mount(AssistantBrandChip, { props: { name } });

describe('AssistantBrandChip', () => {
  beforeEach(() => {
    globalConfig.value = { captainBrandName: 'Tony' };
  });

  it('shows the brand name when the persona has another name', () => {
    expect(mountChip('Luna').text()).toBe('Tony');
  });

  it('is hidden when the persona is named like the brand', () => {
    expect(mountChip('Tony').text()).toBe('');
    expect(mountChip(' tony ').text()).toBe('');
  });

  it('is hidden when no brand name is configured', () => {
    globalConfig.value = {};
    expect(mountChip('Luna').text()).toBe('');
  });
});
