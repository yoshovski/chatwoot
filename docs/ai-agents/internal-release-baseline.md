# Internal 4.18.0 lab baseline

## References

| Reference | Commit |
|---|---|
| Fork develop before reconciliation | 49b36dbdd64521f4454cc88c9866153647915bce |
| Deployed v4.17.1-internal-v16 / release/4.17.1-internal | 1054655d4e997780a05fff3dd83de28efa0cd16a |
| Upstream v4.18.0 | 9f920b549c14491a4e587687a3eed5d21c6ccc7d |

Task: **CWAI-1**. The task branch starts from fork develop, merges the deployed release history, then merges upstream v4.18.0. Keep this integration history when reviewing/promoting the baseline; rewriting it with a squash would discard ancestry used to track future upstream/custom merges.

## Customization preservation

The deployed release differs from upstream v4.17.1 in 94 files. Upstream 4.18.0 touches 12 of those files. The remaining 82 custom files are byte-for-byte equal to the deployed release after integration. The 12 overlapping files were inspected for retained custom changes. This is a source audit, not proof of end-to-end runtime behavior.

Preserved areas include widget appearance/height/contrast, conversation starters, campaign suggestions, pre-chat and reply-time text, agent identity, options/forms, full-width card carousel, dashboard rich-message rendering, SVG branding, demo pages, and existing internal configuration behavior. Existing takeover behavior is carried forward; the authoritative AI ownership gate proposed in the architecture is future work.

Two merge conflicts required resolution:

- `ChatSendButton.vue`: retain custom light-color contrast fallback and combine it with upstream RTL icon mirroring.
- `db/schema.rb`: retain the latest custom schema version `2026_09_09_130000`; automatic merge retains upstream schema additions and custom columns/indexes. No migration timestamp was renumbered.

Upstream trailing spaces in `config/cable.yml` and `config/features.yml` were removed.

The inherited Heroku review-app deployment check runs only in the upstream repository. This fork uses lab candidates and has no corresponding upstream Heroku review app; backend, frontend and image-build checks remain enabled.

## Validation recorded

- Node 24.19.0; pnpm 10.2.0; frozen-lockfile dependency install.
- Widget and color-helper tests: **39 files, 244 tests passed** with `TZ=UTC`, matching the project's test scripts. A preliminary direct Vitest invocation omitted that timezone and produced six availability failures; the configured timezone resolved them without changing application code.
- ESLint on all 50 custom JavaScript/Vue files: zero errors; three existing dynamic-translation-key warnings.
- Ruby 3.4.4 syntax validation on 29 custom Ruby/Jbuilder files: passed.
- Both deployed custom release and upstream 4.18.0 are ancestors of the merged baseline.
- Working diff whitespace/conflict checks passed.

Full Rails specs, database migration/restore tests, Docker image build, browser checks and lab deployment remain promotion gates. The local Docker daemon is unavailable. Syntax checks do not replace those gates. No tag/image publication or deployment was performed while preparing this baseline.

Reproduce the frontend checks:

```sh
pnpm install --frozen-lockfile
TZ=UTC pnpm exec vitest run app/javascript/widget app/javascript/shared/helpers/specs/colorHelper.spec.js --maxWorkers=2 --minWorkers=1
pnpm exec eslint app/javascript/widget/components/ChatSendButton.vue
git merge-base --is-ancestor v4.17.1-internal-v16 HEAD
git merge-base --is-ancestor v4.18.0 HEAD
```

## Candidate and stable names

```text
v4.18.0-internal-v1-rc1
v4.18.0-internal-v1-rc2
v4.18.0-internal-v1
v4.18.0-internal-v2-rc1
v4.18.0-internal-v2
```

Use a new rc number whenever the build changes. Never overwrite a candidate. The existing Docker workflows accept these tags; edition suffixes remain as currently configured. Creating a tag triggers image publication, so tag creation is a release action after candidate readiness. Record the Git commit and image digest; deploy the digest to the lab.

Stable promotion must retain the tested image digest. The current generic tag workflows rebuild images when another tag is pushed, so they do **not** by themselves guarantee digest-preserving promotion. Before the first stable promotion, introduce a promotion path that verifies candidate/stable Git commits and retags the existing candidate manifest, while preventing the generic build from overwriting that stable tag. This is tracked in CWAI-15.

## Lab acceptance and rollback

1. Build the candidate and run backend/frontend checks plus container build checks.
2. Back up the lab database and record the current image digest. Use isolated lab credentials, datasets and stores.
3. Run migrations on the restored lab database; verify custom widget columns and routes.
4. Check custom colors (including near-white), send buttons in LTR/RTL, starters, campaigns, pre-chat, agent identity, carousel width, forms/options, demo links and SVG favicon.
5. Replay FAQ/product and human-handoff cases with the existing integration. The new runtime stays disabled until its own pilot.
6. Test rollback with the compatible schema or database restore required by the actual migrations. Image rollback alone does not reverse a schema migration.
7. Record results in Huly; promote only after acceptance.

## Audited custom paths

| File | Source audit |
|---|---|
| `.github/workflows/lock.yml` | Identical to deployed release |
| `.github/workflows/nightly_installer.yml` | Identical to deployed release |
| `.github/workflows/publish_ee_docker.yml` | Identical to deployed release |
| `.github/workflows/publish_foss_docker.yml` | Identical to deployed release |
| `.github/workflows/stale.yml` | Identical to deployed release |
| `.rubocop.yml` | Identical to deployed release |
| `app/builders/campaigns/campaign_conversation_builder.rb` | Identical to deployed release |
| `app/controllers/api/v1/accounts/campaigns_controller.rb` | Identical to deployed release |
| `app/controllers/dashboard_controller.rb` | Identical to deployed release |
| `app/controllers/demos_controller.rb` | Identical to deployed release |
| `app/javascript/dashboard/components-next/Campaigns/Pages/CampaignPage/LiveChatCampaign/LiveChatCampaignDialog.vue` | Identical to deployed release |
| `app/javascript/dashboard/components-next/Campaigns/Pages/CampaignPage/LiveChatCampaign/LiveChatCampaignForm.vue` | Identical to deployed release |
| `app/javascript/dashboard/components-next/message/Message.vue` | Identical to deployed release |
| `app/javascript/dashboard/components-next/message/bubbles/Article.vue` | Identical to deployed release |
| `app/javascript/dashboard/components-next/message/bubbles/Cards.vue` | Identical to deployed release |
| `app/javascript/dashboard/components-next/message/bubbles/Form.vue` | Identical to deployed release |
| `app/javascript/dashboard/components-next/ordered-text-list/OrderedTextList.vue` | Identical to deployed release |
| `app/javascript/dashboard/i18n/locale/en/campaign.json` | Identical to deployed release |
| `app/javascript/dashboard/i18n/locale/en/inboxMgmt.json` | Custom/upstream overlap; inspected |
| `app/javascript/dashboard/modules/widget-preview/components/Widget.vue` | Identical to deployed release |
| `app/javascript/dashboard/modules/widget-preview/components/WidgetBody.vue` | Identical to deployed release |
| `app/javascript/dashboard/modules/widget-preview/components/WidgetFooter.vue` | Identical to deployed release |
| `app/javascript/dashboard/modules/widget-preview/components/WidgetHead.vue` | Identical to deployed release |
| `app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue` | Custom/upstream overlap; inspected |
| `app/javascript/dashboard/store/modules/inboxes/channelActions.js` | Identical to deployed release |
| `app/javascript/sdk/IFrameHelper.js` | Identical to deployed release |
| `app/javascript/sdk/bubbleHelpers.js` | Identical to deployed release |
| `app/javascript/sdk/sdk.css` | Identical to deployed release |
| `app/javascript/shared/components/CardButton.vue` | Identical to deployed release |
| `app/javascript/shared/components/ChatCard.vue` | Identical to deployed release |
| `app/javascript/shared/components/ChatCards.vue` | Identical to deployed release |
| `app/javascript/shared/components/ChatForm.vue` | Identical to deployed release |
| `app/javascript/shared/components/ChatOption.vue` | Identical to deployed release |
| `app/javascript/shared/components/ChatOptions.vue` | Identical to deployed release |
| `app/javascript/shared/components/CustomerSatisfaction.vue` | Custom/upstream overlap; inspected |
| `app/javascript/shared/helpers/colorHelper.js` | Identical to deployed release |
| `app/javascript/widget/App.vue` | Identical to deployed release |
| `app/javascript/widget/api/campaign.js` | Identical to deployed release |
| `app/javascript/widget/api/endPoints.js` | Identical to deployed release |
| `app/javascript/widget/assets/scss/views/_conversation.scss` | Identical to deployed release |
| `app/javascript/widget/assets/scss/woot.scss` | Identical to deployed release |
| `app/javascript/widget/components/AgentMessage.vue` | Identical to deployed release |
| `app/javascript/widget/components/AgentMessageBubble.vue` | Custom/upstream overlap; inspected |
| `app/javascript/widget/components/Availability/AvailabilityContainer.vue` | Identical to deployed release |
| `app/javascript/widget/components/Availability/AvailabilityText.vue` | Identical to deployed release |
| `app/javascript/widget/components/ChatFooter.vue` | Identical to deployed release |
| `app/javascript/widget/components/ChatSendButton.vue` | Custom/upstream overlap; inspected |
| `app/javascript/widget/components/ConversationStarters.vue` | Identical to deployed release |
| `app/javascript/widget/components/FileBubble.vue` | Identical to deployed release |
| `app/javascript/widget/components/PreChat/Form.vue` | Identical to deployed release |
| `app/javascript/widget/components/TeamAvailability.vue` | Identical to deployed release |
| `app/javascript/widget/components/UnreadMessage.vue` | Identical to deployed release |
| `app/javascript/widget/components/UnreadMessageList.vue` | Identical to deployed release |
| `app/javascript/widget/components/UserMessage.vue` | Identical to deployed release |
| `app/javascript/widget/components/UserMessageBubble.vue` | Identical to deployed release |
| `app/javascript/widget/components/specs/AgentIdentityRendering.spec.js` | Identical to deployed release |
| `app/javascript/widget/components/template/EmailInput.vue` | Custom/upstream overlap; inspected |
| `app/javascript/widget/components/template/IntegrationCard.vue` | Identical to deployed release |
| `app/javascript/widget/composables/useAvailability.js` | Identical to deployed release |
| `app/javascript/widget/i18n/locale/en.json` | Identical to deployed release |
| `app/javascript/widget/store/modules/appConfig.js` | Identical to deployed release |
| `app/javascript/widget/store/modules/campaign.js` | Identical to deployed release |
| `app/javascript/widget/store/types.js` | Identical to deployed release |
| `app/javascript/widget/views/Campaigns.vue` | Identical to deployed release |
| `app/javascript/widget/views/Home.vue` | Identical to deployed release |
| `app/javascript/widget/views/PreChatForm.vue` | Identical to deployed release |
| `app/listeners/campaign_listener.rb` | Identical to deployed release |
| `app/models/campaign.rb` | Identical to deployed release |
| `app/models/channel/web_widget.rb` | Identical to deployed release |
| `app/views/api/v1/models/_campaign.json.jbuilder` | Identical to deployed release |
| `app/views/api/v1/models/_inbox.json.jbuilder` | Custom/upstream overlap; inspected |
| `app/views/api/v1/models/_widget_message.json.jbuilder` | Identical to deployed release |
| `app/views/api/v1/widget/campaigns/index.json.jbuilder` | Identical to deployed release |
| `app/views/api/v1/widget/configs/create.json.jbuilder` | Identical to deployed release |
| `app/views/api/v1/widget/messages/index.json.jbuilder` | Identical to deployed release |
| `app/views/demos/show.html.erb` | Identical to deployed release |
| `app/views/layouts/vueapp.html.erb` | Custom/upstream overlap; inspected |
| `app/views/widgets/show.html.erb` | Custom/upstream overlap; inspected |
| `config/routes.rb` | Custom/upstream overlap; inspected |
| `db/migrate/20260908060000_add_appearance_settings_to_channel_web_widgets.rb` | Identical to deployed release |
| `db/migrate/20260908070000_add_conversation_starters_and_campaign_suggestions.rb` | Identical to deployed release |
| `db/migrate/20260908180000_add_reply_time_message_to_channel_web_widgets.rb` | Identical to deployed release |
| `db/migrate/20260909120000_add_demo_mode_to_channel_web_widgets.rb` | Identical to deployed release |
| `db/migrate/20260909130000_add_demo_slug_to_channel_web_widgets.rb` | Identical to deployed release |
| `db/schema.rb` | Custom/upstream overlap; inspected |
| `enterprise/app/jobs/enterprise/internal/check_new_versions_job.rb` | Identical to deployed release |
| `enterprise/app/services/internal/reconcile_plan_config_service.rb` | Identical to deployed release |
| `lib/chatwoot_app.rb` | Custom/upstream overlap; inspected |
| `lib/chatwoot_hub.rb` | Identical to deployed release |
| `spec/builders/campaigns/campaign_conversation_builder_spec.rb` | Identical to deployed release |
| `spec/controllers/demos_controller_spec.rb` | Identical to deployed release |
| `spec/lib/chatwoot_hub_spec.rb` | Identical to deployed release |
| `spec/listeners/campaign_listener_spec.rb` | Identical to deployed release |
| `spec/models/channel/web_widget_spec.rb` | Identical to deployed release |
