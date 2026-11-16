import { frontendURL } from 'dashboard/helper/URLHelper';
import HomeIndex from './Index.vue';
import GettingStarted from './GettingStarted.vue';
import GuidedSetup from './setup/GuidedSetup.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/home'),
    name: 'account_home',
    component: HomeIndex,
    meta: {
      permissions: ['administrator', 'agent', 'custom_role'],
    },
  },
  {
    path: frontendURL('accounts/:accountId/home/getting-started'),
    name: 'account_home_getting_started',
    component: GettingStarted,
    meta: {
      permissions: ['administrator'],
    },
  },
  {
    path: frontendURL('accounts/:accountId/home/setup/:step?'),
    name: 'account_home_setup',
    component: GuidedSetup,
    meta: {
      permissions: ['administrator'],
    },
  },
];
