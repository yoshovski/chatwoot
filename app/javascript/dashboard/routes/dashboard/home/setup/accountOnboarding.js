import OnboardingAPI from 'dashboard/api/onboarding';

// New accounts open the guided setup right after confirming their email, instead of the upstream account-details form
// (routes/index.js). That form's cursor is closed here: the timezone and language come from the browser, the website
// is already stored from sign-up. The upstream form stays in the code but is no longer on this path.
export const OPEN_STEPS = ['account_details', 'enrichment', 'inbox_setup'];

// The first browser language the app offers, as its code ('pt-BR' → 'pt_BR', 'de-AT' → 'de'); none when not offered.
export const browserLocale = (languages = [], preferred = []) => {
  const codes = languages.map(language => language.iso_639_1_code);
  return preferred
    .map(tag => tag.replace('-', '_'))
    .flatMap(tag => [tag, tag.split('_')[0]])
    .find(code => codes.includes(code));
};

const browserTimezone = () => Intl.DateTimeFormat().resolvedOptions().timeZone;

export const closeAccountOnboarding = async ({ step, languages }) => {
  let current = step;
  if (current !== 'inbox_setup') {
    const locale = browserLocale(languages, navigator.languages || []);
    const { data } = await OnboardingAPI.update({
      onboarding_step: 'account_details',
      timezone: browserTimezone(),
      ...(locale && { locale }),
    });
    current = data.custom_attributes?.onboarding_step;
  }
  // Cloud installs move on to an inbox step; the setup creates the website chat itself, so that step closes too.
  if (current === 'inbox_setup') {
    await OnboardingAPI.update({ onboarding_step: 'inbox_setup' });
  }
};
