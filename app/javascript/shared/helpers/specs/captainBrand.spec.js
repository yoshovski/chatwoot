import { applyCaptainBrand } from '../captainBrand';

describe('applyCaptainBrand', () => {
  it('replaces the whole word in nested values and leaves keys alone', () => {
    const messages = {
      CAPTAIN: {
        TITLE: 'Captain',
        ITEMS: ['Ask Captain', 'Other'],
        NESTED: { TEXT: 'Welcome to Captain AI' },
      },
    };
    expect(applyCaptainBrand(messages, 'Tony')).toEqual({
      CAPTAIN: {
        TITLE: 'Tony',
        ITEMS: ['Ask Tony', 'Other'],
        NESTED: { TEXT: 'Welcome to Tony AI' },
      },
    });
  });

  it('handles the possessive form', () => {
    expect(applyCaptainBrand({ A: "Captain's answers" }, 'Tony')).toEqual({
      A: "Tony's answers",
    });
  });

  it('does not touch words that merely contain captain', () => {
    const messages = {
      A: 'captain_assistant',
      B: 'Captains rule',
      C: 'MyCaptain',
    };
    expect(applyCaptainBrand(messages, 'Tony')).toEqual(messages);
  });

  it('replaces the word inside non-English strings', () => {
    expect(
      applyCaptainBrand({ A: 'Настройки на Captain за вашия акаунт' }, 'Tony')
    ).toEqual({ A: 'Настройки на Tony за вашия акаунт' });
  });

  it('inserts names containing replacement patterns literally', () => {
    expect(applyCaptainBrand({ A: 'Captain' }, 'T$&ny')).toEqual({
      A: 'T$&ny',
    });
  });

  it('returns the messages untouched when the name is Captain or empty', () => {
    const messages = { A: 'Captain' };
    expect(applyCaptainBrand(messages, 'Captain')).toBe(messages);
    expect(applyCaptainBrand(messages, '')).toBe(messages);
    expect(applyCaptainBrand(messages, undefined)).toBe(messages);
  });
});
