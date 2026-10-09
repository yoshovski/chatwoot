import { describe, it, expect, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import {
  SCENARIO_TEMPLATES,
  getTemplateById,
  resolveToolLink,
} from './scenarioTemplates';
import TemplateStepperDialog from './TemplateStepperDialog.vue';

const sampleTools = [
  { id: 'faq_lookup', emoji: '📚', title: 'Search knowledge' },
  { id: 'catalog_product_search', emoji: '🛍️', title: 'Find products' },
  { id: 'track_order', emoji: '📦', title: 'Track an order' },
  { id: 'handoff', emoji: '🙋', title: 'Hand off to a person' },
  { id: 'add_private_note', emoji: '📝', title: 'Add a private note' },
  { id: 'add_label_to_conversation', emoji: '🏷️', title: 'Add a label' },
];

describe('scenarioTemplates', () => {
  describe('resolveToolLink', () => {
    it('formats markdown link when tool is available', () => {
      const link = resolveToolLink(
        'faq_lookup',
        'Search knowledge',
        sampleTools
      );
      expect(link).toBe('[@Search knowledge](tool://faq_lookup)');
    });

    it('returns plain default title when tool is not available', () => {
      const link = resolveToolLink('faq_lookup', 'Search knowledge', []);
      expect(link).toBe('Search knowledge');
    });
  });

  describe('template build deterministic generation', () => {
    SCENARIO_TEMPLATES.forEach(template => {
      describe(template.title, () => {
        it('builds description <= 500 chars with defaults', () => {
          const result = template.build({}, sampleTools);
          expect(result.description.length).toBeLessThanOrEqual(500);
          expect(result.description).toMatch(/^Use when/);
        });

        it('includes only available tool links', () => {
          const resultWithTools = template.build({}, sampleTools);
          const toolMatches = [
            ...(resultWithTools.instruction.matchAll(/tool:\/\/([^)]+)/g) ||
              []),
          ].map(m => m[1]);

          const sampleIds = sampleTools.map(t => t.id);
          toolMatches.forEach(id => {
            expect(sampleIds).toContain(id);
          });

          // With empty tools list, no tool:// links should be present
          const resultNoTools = template.build({}, []);
          expect(resultNoTools.instruction).not.toContain('tool://');
        });

        it('includes custom or default label when template uses label', () => {
          const labelQuestion = template.questions.find(q => q.key === 'label');
          if (labelQuestion) {
            const customLabel = 'custom_tag_123';
            const result = template.build({ label: customLabel }, sampleTools);
            expect(result.instruction).toContain(customLabel);
          }
        });
      });
    });
  });

  describe('TemplateStepperDialog', () => {
    const mountStepper = (props = {}) => {
      return mount(TemplateStepperDialog, {
        props: {
          tools: sampleTools,
          assistant: { link_allowlist: ['cal.com'] },
          ...props,
        },
        global: {
          mocks: {
            $t: (msg, vars) =>
              typeof vars === 'object' ? JSON.stringify(vars) : msg,
          },
          stubs: {
            Dialog: {
              template: '<div><slot /><slot name="footer" /></div>',
              methods: { open: vi.fn(), close: vi.fn() },
            },
            ScenarioForm: {
              props: ['instruction'],
              template: '<div class="stub-editor">{{ instruction }}</div>',
              methods: { validate: () => true },
            },
            Input: {
              props: ['modelValue'],
              template: '<input :value="modelValue" />',
            },
            TextArea: {
              props: ['modelValue'],
              template: '<textarea :value="modelValue" />',
            },
          },
        },
      });
    };

    it('shows preview with built instruction at the final step', async () => {
      const template = getTemplateById('request_a_quote');
      const wrapper = mountStepper({ template });

      // Step through all questions to reach Preview
      for (let i = 0; i < template.questions.length; i += 1) {
        wrapper.vm.goToNext();
      }
      await nextTick();

      expect(wrapper.vm.isPreviewStep).toBe(true);
      expect(wrapper.vm.previewData.title).toBe('Request a quote');
      expect(wrapper.vm.previewData.description).toContain('Use when');
      expect(wrapper.vm.previewData.instruction).toContain(
        'guide them through the quote request'
      );
      expect(wrapper.find('.stub-editor').text()).toContain(
        'guide them through the quote request'
      );
    });

    it('asks to allowlist an unknown host on save for Book a call template', async () => {
      const template = getTemplateById('book_a_call');
      const wrapper = mountStepper({
        template,
        assistant: { link_allowlist: ['cal.com'] },
      });

      // Set booking URL with unknown host
      wrapper.vm.answers.booking_url = 'https://unknown-scheduler.org/book';

      // Step through to Preview
      for (let i = 0; i < template.questions.length; i += 1) {
        wrapper.vm.goToNext();
      }
      await nextTick();

      // Trigger save
      await wrapper.vm.saveScenario();
      await nextTick();

      expect(wrapper.vm.showAllowlistConfirm).toBe(true);
      expect(wrapper.vm.pendingHost).toBe('unknown-scheduler.org');
      expect(wrapper.emitted('add')).toBeFalsy();
    });

    it('does not ask to allowlist when host is already in allowlist', async () => {
      const template = getTemplateById('book_a_call');
      const wrapper = mountStepper({
        template,
        assistant: { link_allowlist: ['cal.com'] },
      });

      wrapper.vm.answers.booking_url = 'https://cal.com/team/demo';

      for (let i = 0; i < template.questions.length; i += 1) {
        wrapper.vm.goToNext();
      }
      await nextTick();

      await wrapper.vm.saveScenario();
      await nextTick();

      expect(wrapper.vm.showAllowlistConfirm).toBe(false);
      expect(wrapper.emitted('add')).toBeTruthy();
      expect(wrapper.emitted('add')[0][0].title).toBe('Book a call');
    });
  });
});
