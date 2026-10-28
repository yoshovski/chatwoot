import { frontendURL } from 'dashboard/helper/URLHelper';
import HomeIndex from './Index.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/home'),
    name: 'account_home',
    component: HomeIndex,
    meta: {
      permissions: ['administrator', 'agent', 'custom_role'],
    },
  },
];
