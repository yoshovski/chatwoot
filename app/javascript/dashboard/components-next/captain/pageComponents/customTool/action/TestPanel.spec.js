import { mount, flushPromises } from '@vue/test-utils';
import TestPanel from './TestPanel.vue';

const mocks = vi.hoisted(() => ({ test: vi.fn() }));

vi.mock('dashboard/api/captain/customTools', () => ({
  default: { test: mocks.test },
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values) => `${key}${values ? JSON.stringify(values) : ''}`,
  }),
}));

const ButtonStub = {
  props: ['label'],
  emits: ['click'],
  template:
    '<button type="button" @click="$emit(\'click\')">{{ label }}</button>',
};

const buildForm = (overrides = {}) => ({
  title: 'Lookup',
  description: '',
  param_schema: [],
  steps: [
    {
      key: 'lookup',
      type: 'request',
      method: 'GET',
      url: 'https://example.com',
      headers: [],
      auth: { type: 'none' },
    },
  ],
  outputs: [],
  execution_mode: 'background',
  messages: {},
  response_template: '',
  ...overrides,
});

const response = {
  steps: [
    {
      key: 'lookup',
      type: 'request',
      ok: true,
      status: 200,
      duration_ms: 12,
      request: { method: 'GET', url: 'https://example.com' },
      response: {
        customer: { email: 'a@b.c' },
        items: [{ sku: 'A-1' }, { sku: 'B-2' }],
      },
    },
  ],
  outputs: {},
  error_kind: null,
};

const mountPanel = (form, stepKey = form.steps[0].key) =>
  mount(TestPanel, {
    props: { form, stepKey, toolId: 4 },
    global: { stubs: { Button: ButtonStub } },
  });

const runTest = wrapper =>
  wrapper.find('[data-test="run-test"]').trigger('click');

const clickKey = (wrapper, label) =>
  wrapper
    .findAll('[data-test="json-key"]')
    .find(node => node.text() === `${label}:`)
    .trigger('click');

describe('TestPanel', () => {
  beforeEach(() => {
    mocks.test.mockReset();
    mocks.test.mockResolvedValue({ data: response });
  });

  it('runs the action up to its step with the saved tool id', async () => {
    const wrapper = mountPanel(buildForm());

    await runTest(wrapper);
    await flushPromises();

    expect(mocks.test).toHaveBeenCalledWith(
      expect.objectContaining({ title: 'Lookup' }),
      {
        id: 4,
        stop_after: 'lookup',
      }
    );
    expect(wrapper.text()).toContain('a@b.c');
    expect(wrapper.emitted('update:result')[0][0]).toEqual(response);
  });

  it('says when an earlier step stopped the run', async () => {
    const form = buildForm({
      steps: [
        ...buildForm().steps,
        { key: 'check', type: 'verify', left: 'a', right: 'b' },
      ],
    });
    mocks.test.mockResolvedValue({
      data: {
        steps: [{ key: 'lookup', ok: false, error: 'Not found' }],
        outputs: {},
      },
    });
    const wrapper = mountPanel(form, 'check');

    await runTest(wrapper);
    await flushPromises();

    expect(wrapper.text()).toContain('EARLIER_FAILED');
    expect(wrapper.text()).toContain('Not found');
  });

  it('saves a clicked field as an output with a de-duplicated key', async () => {
    const wrapper = mountPanel(
      buildForm({ outputs: [{ key: 'email', step: 'other', path: 'email' }] })
    );
    await runTest(wrapper);
    await flushPromises();

    await clickKey(wrapper, 'email');

    expect(wrapper.emitted('addOutput')[0][0]).toMatchObject({
      key: 'email_2',
      step: 'lookup',
      path: 'customer.email',
      type: 'string',
    });
  });

  it('asks whether to save one array item or every item', async () => {
    const wrapper = mountPanel(buildForm());
    await runTest(wrapper);
    await flushPromises();

    const skuKeys = wrapper
      .findAll('[data-test="json-key"]')
      .filter(node => node.text() === 'sku:');
    await skuKeys[0].trigger('click');
    expect(wrapper.find('[data-test="item-choice"]').exists()).toBe(true);

    await wrapper
      .find('[data-test="item-choice"]')
      .findAll('button')[1]
      .trigger('click');
    expect(wrapper.emitted('addOutput')[0][0]).toMatchObject({
      path: 'items[*].sku',
      type: 'array',
    });

    await skuKeys[0].trigger('click');
    await wrapper
      .find('[data-test="item-choice"]')
      .findAll('button')[0]
      .trigger('click');
    expect(wrapper.emitted('addOutput')[1][0]).toMatchObject({
      path: 'items[0].sku',
      type: 'string',
    });
  });

  it('marks saved paths and focuses the output instead of adding it again', async () => {
    const wrapper = mountPanel(
      buildForm({
        outputs: [{ key: 'email', step: 'lookup', path: 'customer.email' }],
      })
    );
    await runTest(wrapper);
    await flushPromises();

    expect(wrapper.find('[data-test="json-saved"]').exists()).toBe(true);
    await clickKey(wrapper, 'email');

    expect(wrapper.emitted('addOutput')).toBeUndefined();
    expect(wrapper.emitted('focusOutput')[0]).toEqual(['email']);
  });

  it('warns before running steps that change data', async () => {
    const wrapper = mountPanel(
      buildForm({
        steps: [
          {
            key: 'cancel',
            type: 'request',
            method: 'POST',
            url: 'https://example.com',
            headers: [],
            auth: { type: 'none' },
          },
        ],
      })
    );

    await runTest(wrapper);
    expect(mocks.test).not.toHaveBeenCalled();
    expect(wrapper.find('[data-test="change-warning"]').exists()).toBe(true);

    await wrapper
      .find('[data-test="change-warning"]')
      .find('button')
      .trigger('click');
    await flushPromises();
    expect(mocks.test).toHaveBeenCalledOnce();
  });
});
