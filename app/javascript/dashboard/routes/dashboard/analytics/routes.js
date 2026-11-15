import { frontendURL } from 'dashboard/helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import AnalyticsIndex from './Index.vue';
import OverviewTab from './OverviewTab.vue';
import AiAgentTab from './AiAgentTab.vue';
import TeamTab from './TeamTab.vue';
import RatingTab from './RatingTab.vue';
import ReportsHub from './ReportsHub.vue';

const meta = {
  featureFlag: FEATURE_FLAGS.REPORTS,
  permissions: ['administrator', 'report_manage'],
};

const VIEWS = [
  { name: 'analytics_overview', path: 'overview', component: OverviewTab },
  { name: 'analytics_ai_agent', path: 'ai-agent', component: AiAgentTab },
  { name: 'analytics_team', path: 'team', component: TeamTab },
  { name: 'analytics_rating', path: 'rating', component: RatingTab },
  { name: 'analytics_reports', path: 'reports', component: ReportsHub },
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
      ...VIEWS.map(view => ({ ...view, meta })),
    ],
  },
];
