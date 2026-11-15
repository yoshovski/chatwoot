import { frontendURL } from 'dashboard/helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import AnalyticsIndex from './Index.vue';
import OverviewTab from './OverviewTab.vue';
import PendingTab from './PendingTab.vue';

const meta = {
  featureFlag: FEATURE_FLAGS.REPORTS,
  permissions: ['administrator', 'report_manage'],
};

export const TABS = [
  { key: 'OVERVIEW', name: 'analytics_overview', path: 'overview' },
  { key: 'AI_AGENT', name: 'analytics_ai_agent', path: 'ai-agent' },
  { key: 'TEAM', name: 'analytics_team', path: 'team' },
  { key: 'RATING', name: 'analytics_rating', path: 'rating' },
];

export const routes = [
  {
    path: frontendURL('accounts/:accountId/analytics'),
    component: AnalyticsIndex,
    meta,
    children: [
      {
        path: '',
        name: 'analytics_index',
        meta,
        redirect: to => ({
          name: 'analytics_overview',
          params: to.params,
          query: to.query,
        }),
      },
      ...TABS.map(tab => ({
        path: tab.path,
        name: tab.name,
        meta,
        component: tab.name === 'analytics_overview' ? OverviewTab : PendingTab,
      })),
    ],
  },
];
