import { FEATURE_FLAGS } from '../../../../featureFlags';
import { frontendURL } from '../../../../helper/URLHelper';
import ChannelFactory from './ChannelFactory.vue';

import SettingsWrapper from '../SettingsWrapper.vue';
import InboxHome from './Index.vue';
import ChannelSettings from './ChannelSettings.vue';
import InboxChannel from './InboxChannels.vue';
import ChannelList from './ChannelList.vue';
import AddAgents from './AddAgents.vue';
import FinishSetup from './FinishSetup.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/inboxes/:pathMatch(.*)*'),
      redirect: to => {
        const parts = to.params.pathMatch || [];
        const suffix = parts.join('/') === 'list' ? '' : parts.join('/');
        return {
          path: frontendURL(
            `accounts/${to.params.accountId}/channels${suffix ? `/${suffix}` : ''}`
          ),
          query: to.query,
          hash: to.hash,
        };
      },
    },
    {
      path: frontendURL('accounts/:accountId/channels'),
      component: SettingsWrapper,
      props: { keepAlive: false },
      children: [
        {
          path: '',
          name: 'settings_inbox_list',
          component: InboxHome,
          meta: {
            tinted: true,
            featureFlag: FEATURE_FLAGS.INBOX_MANAGEMENT,
            permissions: ['administrator'],
          },
        },
        {
          path: 'new',
          component: InboxChannel,
          children: [
            {
              path: '',
              name: 'settings_inbox_new',
              component: ChannelList,
              meta: {
                tinted: true,
                featureFlag: FEATURE_FLAGS.INBOX_MANAGEMENT,
                permissions: ['administrator'],
              },
            },
            {
              path: ':inbox_id/finish',
              name: 'settings_inbox_finish',
              component: FinishSetup,
              meta: {
                featureFlag: FEATURE_FLAGS.INBOX_MANAGEMENT,
                permissions: ['administrator'],
              },
            },
            {
              path: ':sub_page',
              name: 'settings_inboxes_page_channel',
              component: ChannelFactory,
              props: route => ({ channelName: route.params.sub_page }),
              meta: {
                featureFlag: FEATURE_FLAGS.INBOX_MANAGEMENT,
                permissions: ['administrator'],
              },
            },
            {
              path: ':inbox_id/agents',
              name: 'settings_inboxes_add_agents',
              component: AddAgents,
              meta: {
                featureFlag: FEATURE_FLAGS.INBOX_MANAGEMENT,
                permissions: ['administrator'],
              },
            },
          ],
        },
        {
          path: ':inboxId/:tab?',
          name: 'settings_inbox_show',
          component: ChannelSettings,
          meta: {
            tinted: true,
            reuseOnTabChange: true,
            featureFlag: FEATURE_FLAGS.INBOX_MANAGEMENT,
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
