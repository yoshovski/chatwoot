import OnboardingAPI from 'dashboard/api/onboarding';
import { browserLocale, closeAccountOnboarding } from './accountOnboarding';

vi.mock('dashboard/api/onboarding', () => ({ default: { update: vi.fn() } }));

const LANGUAGES = [
  { iso_639_1_code: 'en' },
  { iso_639_1_code: 'de' },
  { iso_639_1_code: 'pt_BR' },
];

describe('browserLocale', () => {
  it('picks the first browser language the app offers', () => {
    expect(browserLocale(LANGUAGES, ['pt-BR', 'en'])).toBe('pt_BR');
    expect(browserLocale(LANGUAGES, ['de-AT', 'en'])).toBe('de');
    expect(browserLocale(LANGUAGES, ['ja', 'en-GB'])).toBe('en');
  });

  it('returns nothing when no browser language is offered', () => {
    expect(browserLocale(LANGUAGES, ['ja'])).toBeUndefined();
  });
});

describe('closeAccountOnboarding', () => {
  beforeEach(() => vi.clearAllMocks());

  it('closes the account details with the browser timezone', async () => {
    OnboardingAPI.update.mockResolvedValue({ data: { custom_attributes: {} } });
    await closeAccountOnboarding({ step: 'account_details', languages: [] });

    expect(OnboardingAPI.update).toHaveBeenCalledTimes(1);
    expect(OnboardingAPI.update).toHaveBeenCalledWith({
      onboarding_step: 'account_details',
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    });
  });

  it('also closes the inbox step that cloud installs move on to', async () => {
    OnboardingAPI.update.mockResolvedValueOnce({
      data: { custom_attributes: { onboarding_step: 'inbox_setup' } },
    });
    await closeAccountOnboarding({ step: 'enrichment', languages: [] });

    expect(OnboardingAPI.update).toHaveBeenLastCalledWith({
      onboarding_step: 'inbox_setup',
    });
  });

  it('closes an account already on the inbox step', async () => {
    await closeAccountOnboarding({ step: 'inbox_setup', languages: [] });

    expect(OnboardingAPI.update).toHaveBeenCalledTimes(1);
    expect(OnboardingAPI.update).toHaveBeenCalledWith({
      onboarding_step: 'inbox_setup',
    });
  });
});
