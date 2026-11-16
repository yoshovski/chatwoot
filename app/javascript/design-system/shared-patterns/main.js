import 'dashboard/assets/scss/app.scss';
import '@fontsource-variable/plus-jakarta-sans';
import { createApp, h, ref } from 'vue';
import { createI18n } from 'vue-i18n';
import {
  createRouter,
  createWebHashHistory,
  RouterLink,
  RouterView,
} from 'vue-router';
import { createStore } from 'vuex';
import general from 'dashboard/i18n/locale/en/general.json';
import components from 'dashboard/i18n/locale/en/components.json';
import SharedPatterns from './SharedPatterns.vue';

const layouts = [
  ['collection', 'Collection'],
  ['configuration', 'Configuration'],
  ['summary', 'Summary'],
];

const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: '/', redirect: '/collection' },
    ...layouts.map(([layout]) => ({
      path: `/${layout}`,
      component: SharedPatterns,
      props: { layout },
    })),
  ],
});

const app = createApp({
  setup() {
    const dark = ref(false);

    const toggleTheme = () => {
      dark.value = !dark.value;
      document.documentElement.classList.toggle('dark', dark.value);
    };

    return () =>
      h('div', { class: 'min-h-screen bg-n-background' }, [
        h(
          'nav',
          {
            'aria-label': 'Fixture controls',
            class:
              'mx-auto flex max-w-[80rem] flex-wrap items-center gap-4 px-4 pt-4 text-sm',
          },
          [
            ...layouts.map(([layout, label]) =>
              h(
                RouterLink,
                { to: `/${layout}`, class: 'text-n-blue-11 underline' },
                () => label
              )
            ),
            h(
              'button',
              {
                type: 'button',
                'aria-pressed': dark.value,
                class: 'rounded-lg bg-n-solid-2 px-2 py-1 text-n-slate-12',
                onClick: toggleTheme,
              },
              'Dark theme'
            ),
          ]
        ),
        h(
          RouterView,
          {},
          {
            default: ({ Component, route }) =>
              Component ? h(Component, { key: route.path }) : null,
          }
        ),
      ]);
  },
});

const fixture = {
  SOURCES: 'Knowledge sources',
  PREVIEW_STATE: 'Preview state',
  STATES: {
    ready: 'Populated',
    loading: 'Loading',
    empty: 'First use',
    error: 'Load failed',
    unavailable: 'Unavailable',
  },
  BUSINESS_DETAILS: 'Business details',
  WORKSPACE_IDENTITY: 'Workspace identity',
  WORKSPACE_NAME: 'Workspace name',
  SUPPORT_OVERVIEW: 'Support overview',
};

app.use(
  createI18n({
    legacy: false,
    locale: 'en',
    messages: { en: { ...general, ...components, FIXTURE: fixture } },
  })
);
app.use(createStore({ getters: { 'accounts/isRTL': () => false } }));
app.use(router);
app.mount('#app');
