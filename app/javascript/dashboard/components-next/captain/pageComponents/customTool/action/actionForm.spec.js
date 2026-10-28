import {
  everyItemSegments,
  fromTool,
  moveStep,
  newStep,
  outputFromPick,
  pathFromSegments,
  removeStep,
  sameAsOptions,
  templateParts,
  toPayload,
  uniqueKey,
  usedParams,
  variablesBefore,
} from './actionForm';

const lookup = { key: 'lookup', type: 'request', method: 'GET', url: '' };
const check = { key: 'check', type: 'verify', left: '', right: '' };
const cancel = { key: 'cancel', type: 'request', method: 'POST', url: '' };

describe('actionForm', () => {
  describe('step list', () => {
    it('moves a step up or down and ignores moves past the ends', () => {
      const steps = [lookup, check, cancel];

      expect(moveStep(steps, 2, -1).map(step => step.key)).toEqual([
        'lookup',
        'cancel',
        'check',
      ]);
      expect(moveStep(steps, 0, -1)).toBe(steps);
      expect(moveStep(steps, 2, 1)).toBe(steps);
    });

    it('removes a step together with the outputs saved from it', () => {
      const outputs = [
        { key: 'order_id', step: 'lookup' },
        { key: 'status', step: 'cancel' },
      ];

      const result = removeStep([lookup, check, cancel], outputs, 0);

      expect(result.steps.map(step => step.key)).toEqual(['check', 'cancel']);
      expect(result.outputs).toEqual([{ key: 'status', step: 'cancel' }]);
    });

    it('gives new steps unique keys', () => {
      expect(
        newStep('request', [lookup, { ...cancel, key: 'request' }]).key
      ).toBe('request_2');
      expect(newStep('verify', [check]).key).toBe('check_2');
    });
  });

  describe('variablesBefore', () => {
    const form = {
      param_schema: [{ name: 'order_number' }, { name: '' }],
      steps: [lookup, check, cancel],
      outputs: [
        { key: 'order_id', step: 'lookup' },
        { key: 'result', step: 'cancel' },
      ],
    };

    it('offers inputs, contact fields and only outputs of earlier steps', () => {
      expect(variablesBefore(form, 2)).toEqual({
        inputs: ['order_number'],
        outputs: ['outputs.order_id'],
        contact: ['contact.email', 'contact.phone_number', 'contact.name'],
      });
      expect(variablesBefore(form, 0).outputs).toEqual([]);
    });
  });

  describe('outputs from a response click', () => {
    it('builds the path in the backend syntax', () => {
      expect(pathFromSegments(['order', 'items', 0, 'sku'])).toBe(
        'order.items[0].sku'
      );
      expect(pathFromSegments(['meta', 'x.y', 'say "hi"'])).toBe(
        'meta["x.y"]["say \\"hi\\""]'
      );
      expect(pathFromSegments([0, 'id'])).toBe('[0].id');
    });

    it('uses the clicked key and de-duplicates it', () => {
      const outputs = [{ key: 'email' }, { key: 'email_2' }];

      expect(
        outputFromPick(
          {
            stepKey: 'lookup',
            segments: ['customer', 'email'],
            value: 'a@b.c',
          },
          outputs
        )
      ).toEqual({
        key: 'email_3',
        step: 'lookup',
        path: 'customer.email',
        type: 'string',
        available_to_ai: true,
        required: false,
      });
    });

    it('saves one item with [0] or every item with [*]', () => {
      const segments = ['items', 0, 'qty'];

      expect(
        outputFromPick({ stepKey: 'lookup', segments, value: 2 }, [])
      ).toMatchObject({ key: 'qty', path: 'items[0].qty', type: 'number' });
      expect(
        outputFromPick(
          {
            stepKey: 'lookup',
            segments: everyItemSegments(segments),
            value: 2,
          },
          []
        )
      ).toMatchObject({ key: 'qty', path: 'items[*].qty', type: 'array' });
    });

    it('names an output after the step when the click has no key', () => {
      expect(uniqueKey('Order-ID!', [])).toBe('order_id');
      expect(
        outputFromPick({ stepKey: 'lookup', segments: [0], value: {} }, [])
      ).toMatchObject({ key: 'lookup', type: 'object' });
    });
  });

  describe('templateParts', () => {
    it('splits a template into text and variables', () => {
      expect(
        templateParts(
          'example.com/orders/{{ order_number }}?e={{outputs.email}}'
        )
      ).toEqual([
        { text: 'example.com/orders/' },
        { variable: 'order_number', raw: '{{ order_number }}' },
        { text: '?e=' },
        { variable: 'outputs.email', raw: '{{outputs.email}}' },
      ]);
    });

    it('returns nothing for a blank template', () => {
      expect(templateParts('')).toEqual([]);
      expect(templateParts(undefined)).toEqual([]);
    });
  });

  describe('usedParams', () => {
    it('returns the inputs the steps up to the given one read', () => {
      const form = {
        param_schema: [
          { name: 'order_number' },
          { name: 'email' },
          { name: 'reason' },
        ],
        steps: [
          { ...lookup, url: 'https://example.com/{{ order_number | upcase }}' },
          { ...check, left: '{{ email }}', right: 'x' },
          { ...cancel, body: '{"reason": "{{ reason }}"}' },
        ],
      };

      expect(usedParams(form, 'lookup').map(param => param.name)).toEqual([
        'order_number',
      ]);
      expect(usedParams(form, 'cancel')).toHaveLength(3);
    });
  });

  describe('payload', () => {
    it('leaves out blank secrets, empty headers and blank messages', () => {
      const form = fromTool({
        title: 'Lookup',
        steps: [
          {
            ...lookup,
            headers: [{ name: '', value: 'x' }],
            auth: { type: 'api_key', name: 'X-Key' },
            auth_configured: true,
          },
        ],
        messages: { success: 'Done' },
      });

      const payload = toPayload(form);

      expect(payload.steps[0].auth).toEqual({ type: 'api_key', name: 'X-Key' });
      expect(payload.steps[0]).not.toHaveProperty('auth_configured');
      expect(payload.steps[0].headers).toEqual([]);
      expect(payload.messages).toEqual({ success: 'Done' });
    });

    it("shows the action's auth on the first request and reuses it on later ones", () => {
      const form = fromTool({
        auth_type: 'bearer',
        auth_configured: true,
        steps: [lookup, check, cancel],
      });

      expect(form.steps[0].auth).toMatchObject({ type: 'bearer' });
      expect(form.steps[2].auth).toEqual({ same_as: 'lookup' });
      expect(toPayload(form).steps[2].auth).toEqual({ same_as: 'lookup' });
    });
  });

  describe('auth per request', () => {
    const withAuth = { ...lookup, auth: { type: 'bearer' } };

    it('starts a new request with the auth of the first request that has one', () => {
      expect(newStep('request', [withAuth]).auth).toEqual({
        same_as: 'lookup',
      });
      expect(
        newStep('request', [{ ...lookup, auth: { type: 'none' } }]).auth
      ).toEqual({ type: 'none' });
    });

    it('drops a reused auth that no longer points to an earlier request', () => {
      const steps = [withAuth, { ...cancel, auth: { same_as: 'lookup' } }];

      expect(moveStep(steps, 0, 1)[0].auth).toEqual({ type: 'none' });
      expect(removeStep(steps, [], 0).steps[0].auth).toEqual({ type: 'none' });
    });

    it('offers only earlier requests that have their own auth', () => {
      const steps = [
        withAuth,
        check,
        { ...cancel, auth: { same_as: 'lookup' } },
        lookup,
      ];

      expect(sameAsOptions(steps, 3)).toEqual([{ key: 'lookup', number: 1 }]);
    });
  });
});
