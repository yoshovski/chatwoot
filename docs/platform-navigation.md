# Platform navigation

ChatOctave uses a product rail and a contextual sidebar. The rail remains stable; the sidebar contains only the selected area's destinations. Existing URLs, route permissions, installation restrictions, feature gates, conversation counts and saved-view sorting continue to apply.

## Product areas

- Conversations includes My Inbox, conversation views, teams, channels and labels.
- Octave includes AI agents, Overview, Knowledge (Data sources, FAQs, Suggestions and connected Products), Behavior (Instructions, Boundaries, Handoff and After the chat), Actions, Test agent, Channels and Configure.
- Customers includes Contacts, Companies and existing contact segments.
- Calls, Reports and Campaigns retain their existing destinations.
- Help Center retains articles, categories, locales and configuration.
- Settings groups workspace administration, services, workflows, data and billing.
- The optional native knowledge library remains a separate destination under its existing feature flag; it is not merged into an agent's knowledge.

Selecting a rail icon returns to that area's last visited page during the current session. Account switches clear remembered destinations. Direct links select the correct area and expand its active group. Rail icons have accessible names and tooltips. Mobile navigation remains behind the existing drawer launcher.

## AI agents

The AI agents destination lists existing agents and offers creation directly. New AI agent is also available next to the sidebar agent selector for administrators. With no agent, the destination shows a clear creation state. Creation opens the new agent's overview; channel assignment remains a separate action. Switching agents preserves the current agent-specific page. Behavior and configuration no longer introduce another navigation column.

## Knowledge

The initial data-source view groups imported documents by exact website host; uploaded files form a separate group. Manage pages opens the website's imported documents. A folder dropdown narrows those documents by their existing website section. All sources provides the ungrouped list.

Search, source type, synchronization state, sorting, website and folder filters intersect. Counts and pagination describe matching documents. Filters and page changes clear stale document selection. Bulk actions act on explicitly selected documents; browsing a folder does not select its contents. Website discovery/selection remains available to administrators within its website.

Website and folder filtering resolve the assistant through `Current.account.captain_assistants`. A website name never identifies a tenant, and another account's assistant cannot be used to filter documents.

## Shopify availability

Use Super Admin → Accounts → Edit → Shopify Integration to enable or disable the existing account feature. New accounts default to disabled. Stored feature bits for existing accounts are preserved; this change does not disconnect stores or delete credentials, documents or remote catalog data.

The installation-wide `ENABLE_SHOPIFY_INTEGRATION` switch must also be enabled. The account response exposes the effective feature state. Unchecked feature values are saved as disabled; features omitted from the form retain their current state.

Disabled accounts do not fetch Shopify status from the navigation, see Products navigation, receive a connection offer in Knowledge, or access the Shopify integration API. Catalog retrieval, commerce tools and product-card enrichment also respect availability. Connection setup lives in Settings → Integrations. Products appears after a store has been connected. Administrators manage integrations; agents retain their existing read permissions.

Disabling the ChatOctave feature does not revoke credentials for the separate Shopify Agent Tools service or stop its independently configured webhooks and catalog jobs. Pause or disconnect that service explicitly when operational shutdown is required.

## Verification

Review the rail with an administrator and a restricted agent, open behavior and knowledge URLs directly, create an agent, switch agents, browse websites and folders, search within a website, clear filters and change pages after selecting documents. Verify Shopify changes independently for two accounts, including disabling a connected store. The feature must remain hidden when the installation-wide switch is off.
