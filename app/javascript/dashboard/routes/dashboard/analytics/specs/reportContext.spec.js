import { mount, flushPromises } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import Index from '../Index.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
    locale: { value: 'en-US' },
  }),
}));

it('preserves Overview ranges through refresh, tab navigation and history', async () => {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      {
        path: '/analytics',
        component: Index,
        children: [
          {
            path: 'ai-agent',
            name: 'analytics_ai_agent',
            component: {
              props: ['period'],
              template: '<p data-period>{{ period }}</p>',
            },
          },
          {
            path: 'team',
            name: 'analytics_team',
            component: {
              props: ['period'],
              template: '<p data-period>{{ period }}</p>',
            },
          },
        ],
      },
    ],
  });
  await router.push('/analytics/ai-agent?period=90');
  const wrapper = mount(Index, {
    global: {
      plugins: [router],
      stubs: {
        PageFrame: { template: '<main><slot name="header" /><slot /></main>' },
        PageHeader: {
          props: ['description'],
          template: '<header>{{ description }}<slot name="action" /></header>',
        },
        RangeSelector: {
          props: ['modelValue'],
          emits: ['update:modelValue'],
          template:
            "<button @click=\"$emit('update:modelValue', 'last_month')\">{{ modelValue }}</button>",
        },
      },
    },
  });
  await flushPromises();
  expect(wrapper.get('button').text()).toBe('90');
  expect(wrapper.text()).toContain('ANALYTICS.CONTEXT');
  await wrapper.get('button').trigger('click');
  await flushPromises();
  expect(router.currentRoute.value.query.period).toBe('last_month');
  await router.push({
    name: 'analytics_team',
    query: router.currentRoute.value.query,
  });
  await flushPromises();
  expect(wrapper.get('button').text()).toBe('last_month');
  router.back();
  await flushPromises();
  router.back();
  await flushPromises();
  expect(wrapper.get('button').text()).toBe('90');
  await router.push('/analytics/ai-agent?period=365');
  await flushPromises();
  expect(wrapper.get('[role="status"]').text()).toContain(
    'ANALYTICS.UNSUPPORTED_PERIOD'
  );
  wrapper.unmount();
});
