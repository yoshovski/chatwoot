import {
  SCENARIO_TEMPLATES,
  allowlistEntryFor,
  buildFromTemplate,
  getTemplateById,
  isLinkAllowed,
  resolveToolLink,
} from './scenarioTemplates';

const sampleTools = [
  { id: 'faq_lookup', title: 'Search knowledge' },
  { id: 'catalog_product_search', title: 'Find products' },
  { id: 'track_order', title: 'Track an order' },
  { id: 'handoff', title: 'Hand off to a person' },
  { id: 'add_private_note', title: 'Add a private note' },
  { id: 'add_label_to_conversation', title: 'Add a label' },
];

const BOOKING_URL = 'https://cal.com/acme/intro';

const answersWithEverything = template =>
  Object.fromEntries(
    template.questions.map(question => {
      if (question.type === 'chips') {
        return [
          question.key,
          [
            ...question.groups.flatMap(group => group.options),
            { custom: true, label: 'Site access hours' },
          ],
        ];
      }
      if (question.type === 'url') return [question.key, BOOKING_URL];
      if (question.type === 'number') return [question.key, 12];
      if (question.type === 'label') return [question.key, 'custom-label'];
      if (question.type === 'select') return [question.key, question.default];
      return [question.key, 'bulk orders'];
    })
  );

const stepNumbers = instruction =>
  [...instruction.matchAll(/^(\d+)\.\s/gm)].map(match => Number(match[1]));

describe('scenarioTemplates', () => {
  describe('resolveToolLink', () => {
    it('links an available tool and falls back to plain text', () => {
      expect(
        resolveToolLink('faq_lookup', 'Search knowledge', sampleTools)
      ).toBe('[@Search knowledge](tool://faq_lookup)');
      expect(resolveToolLink('faq_lookup', 'Search knowledge', [])).toBe(
        'Search knowledge'
      );
    });
  });

  describe.each(SCENARIO_TEMPLATES.map(template => [template.id, template]))(
    '%s',
    (_id, template) => {
      const builds = [
        ['defaults', {}],
        ['every option', answersWithEverything(template)],
      ];

      it.each(builds)('numbers steps without gaps (%s)', (_name, answers) => {
        const { instruction } = buildFromTemplate(
          template,
          { booking_url: BOOKING_URL, ...answers },
          sampleTools
        );
        const numbers = stepNumbers(instruction);

        expect(numbers.length).toBeGreaterThan(2);
        expect(numbers).toEqual(numbers.map((_n, index) => index + 1));
      });

      it('writes a routing description under 500 characters', () => {
        const { description } = buildFromTemplate(template, {}, sampleTools);

        expect(description).toMatch(/^Use when/);
        expect(description.length).toBeLessThanOrEqual(500);
      });

      it('links only available tools', () => {
        const withTools = buildFromTemplate(template, {}, sampleTools);
        const linkedIds = [
          ...withTools.instruction.matchAll(/tool:\/\/([^)]+)/g),
        ].map(match => match[1]);

        expect(linkedIds.length).toBeGreaterThan(0);
        linkedIds.forEach(id =>
          expect(sampleTools.map(tool => tool.id)).toContain(id)
        );
        expect(buildFromTemplate(template, {}, []).instruction).not.toContain(
          'tool://'
        );
      });

      it('writes custom fields and the label verbatim', () => {
        const answers = answersWithEverything(template);
        const { instruction } = buildFromTemplate(
          template,
          answers,
          sampleTools
        );
        const hasChips = template.questions.some(q => q.type === 'chips');
        const hasLabel = template.questions.some(q => q.type === 'label');

        if (hasChips) expect(instruction).toContain('Site access hours');
        if (hasLabel) expect(instruction).toContain('"custom-label"');
      });
    }
  );

  describe('Request a quote', () => {
    const template = getTemplateById('request_a_quote');

    it('collects contact details by default so the team can send the quote', () => {
      const { instruction } = buildFromTemplate(template, {}, sampleTools);

      expect(instruction).toContain('Name and email address');
      expect(instruction).toContain('Hand the chat to the team');
      expect(instruction).toContain('within 1 business day');
    });

    it('keeps the chat with the assistant for the note-only option', () => {
      const { instruction } = buildFromTemplate(
        template,
        {
          after_summary: 'note_only',
          reply_time: 'other',
          reply_time_other: 'within 3 hours',
        },
        sampleTools
      );

      expect(instruction).toContain('send the quote by email within 3 hours');
      expect(instruction).not.toContain('tool://handoff');
    });
  });

  describe('link allowlist', () => {
    it('matches booking links the way reply links are filtered', () => {
      expect(isLinkAllowed(BOOKING_URL, ['https://store.example/'])).toBe(
        false
      );
      expect(isLinkAllowed(BOOKING_URL, ['https://cal.com/'])).toBe(true);
      expect(isLinkAllowed(BOOKING_URL, ['https://cal.com'])).toBe(true);
      expect(isLinkAllowed(BOOKING_URL, ['https://cal.com.evil.test/'])).toBe(
        false
      );
      expect(isLinkAllowed(BOOKING_URL, ['cal.com'])).toBe(false);
    });

    it('allows the whole booking site, not the bare host', () => {
      expect(allowlistEntryFor(BOOKING_URL)).toBe('https://cal.com/');
    });
  });
});
