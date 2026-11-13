import { flushPromises, mount } from '@vue/test-utils';
import { withFullI18n } from 'test-i18n';
import { createStore } from 'vuex';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import SignupForm from '../Form.vue';
import { register } from '../../../../../../api/auth';
import { useAlert } from 'dashboard/composables';

withFullI18n();

const push = vi.fn();
vi.mock('vue-router', () => ({ useRouter: () => ({ push }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('../../../../../../api/auth', () => ({ register: vi.fn() }));

const store = createStore({
  modules: {
    globalConfig: {
      namespaced: true,
      getters: {
        get: () => ({ termsURL: '/terms', privacyURL: '/privacy' }),
      },
    },
  },
});

const mountForm = () =>
  mount(SignupForm, {
    global: {
      plugins: [store],
      stubs: {
        RouterLink: { template: '<a><slot /></a>' },
        Transition: false,
        'fluent-icon': true,
      },
    },
  });

const fillAndSubmit = async (
  wrapper,
  {
    email = 'owner@shop-example.com',
    password = 'Password1!',
    website = 'shop-example.com',
  } = {}
) => {
  await wrapper.find('input[name="email_address"]').setValue(email);
  await wrapper.find('input[name="password"]').setValue(password);
  await wrapper.find('input[name="website"]').setValue(website);
  await wrapper.find('form').trigger('submit');
  await flushPromises();
};

describe('Signup form', () => {
  beforeEach(() => {
    window.chatwootConfig = {};
    vi.clearAllMocks();
  });

  it('shows what is wrong with each field and does not submit', async () => {
    const wrapper = mountForm();
    await fillAndSubmit(wrapper, {
      email: 'not-an-email',
      password: 'short',
      website: 'nope',
    });

    expect(wrapper.text()).toContain(
      'Enter a valid email address, for example you@yourshop.com.'
    );
    expect(wrapper.text()).toContain(
      'Use at least 6 characters, with an uppercase letter'
    );
    expect(wrapper.text()).toContain(
      'Enter your website address, for example yourshop.com.'
    );
    expect(register).not.toHaveBeenCalled();
  });

  it('asks for a work email instead of a personal one', async () => {
    const wrapper = mountForm();
    await fillAndSubmit(wrapper, { email: 'someone@gmail.com' });

    expect(wrapper.text()).toContain('Use your work email.');
    expect(register).not.toHaveBeenCalled();
  });

  it('sends the website and opens "Check your inbox"', async () => {
    register.mockResolvedValue({ email: 'owner@shop-example.com' });
    const wrapper = mountForm();
    await fillAndSubmit(wrapper, { website: ' shop-example.com ' });

    expect(register).toHaveBeenCalledWith(
      expect.objectContaining({
        email: 'owner@shop-example.com',
        website: 'shop-example.com',
      })
    );
    expect(push).toHaveBeenCalledWith(
      expect.objectContaining({ name: 'auth_verify_email' })
    );
  });

  it('says the email already has an account, with a way to log in', async () => {
    register.mockRejectedValue(
      Object.assign(new Error('taken'), { code: 'email_taken' })
    );
    const wrapper = mountForm();
    await fillAndSubmit(wrapper);

    expect(wrapper.text()).toContain(
      'An account with this email already exists.'
    );
    expect(wrapper.find('[data-testid="log_in_instead"]').exists()).toBe(true);
    expect(useAlert).not.toHaveBeenCalled();
  });

  it('says a blocked email domain is not accepted', async () => {
    register.mockRejectedValue(
      Object.assign(new Error('blocked'), { code: 'email_blocked' })
    );
    const wrapper = mountForm();
    await fillAndSubmit(wrapper);

    expect(wrapper.text()).toContain('This email domain is not accepted.');
  });

  it('clears the email error once the email changes', async () => {
    register.mockRejectedValue(
      Object.assign(new Error('taken'), { code: 'email_taken' })
    );
    const wrapper = mountForm();
    await fillAndSubmit(wrapper);
    await wrapper
      .find('input[name="email_address"]')
      .setValue('other@shop-example.com');

    expect(wrapper.text()).not.toContain('already exists');
  });

  it('shows any other error as a toast', async () => {
    register.mockRejectedValue(new Error('Signup failed'));
    const wrapper = mountForm();
    await fillAndSubmit(wrapper);

    expect(useAlert).toHaveBeenCalledWith('Signup failed');
  });
});
