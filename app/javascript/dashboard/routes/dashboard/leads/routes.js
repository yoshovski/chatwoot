import { INSTALLATION_TYPES } from 'dashboard/constants/installationTypes';
import { frontendURL } from 'dashboard/helper/URLHelper';
import LeadsIndex from './Index.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/leads'),
    name: 'leads_index',
    component: LeadsIndex,
    meta: {
      permissions: ['administrator', 'agent'],
      installationTypes: [
        INSTALLATION_TYPES.CLOUD,
        INSTALLATION_TYPES.ENTERPRISE,
      ],
    },
  },
];
