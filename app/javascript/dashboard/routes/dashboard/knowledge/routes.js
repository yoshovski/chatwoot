import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { frontendURL } from 'dashboard/helper/URLHelper';
import Library from './Library.vue';

const meta = {
  permissions: ['administrator', 'agent'],
  featureFlag: FEATURE_FLAGS.NATIVE_AI_KNOWLEDGE,
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/knowledge'),
    name: 'native_knowledge_index',
    component: Library,
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/knowledge/:baseId'),
    name: 'native_knowledge_show',
    component: Library,
    meta,
  },
];
