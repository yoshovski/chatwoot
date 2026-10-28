// Form helpers for the action page: step list edits, the variables a step may use, and outputs saved by clicking
// a value in a test response. Paths match the backend's Captain::Tools::ResponsePath syntax.
export const MAX_STEPS = { request: 3, verify: 2 };
export const REQUEST_METHODS = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];
export const COMPARISONS = ['exact', 'case_insensitive', 'email', 'phone'];
export const CONTACT_FIELDS = ['email', 'phone_number', 'name'];
export const OUTPUT_TYPES = ['string', 'number', 'boolean', 'array', 'object'];
export const SECRET_AUTH_KEYS = ['token', 'password', 'key'];
export const AUTH_TYPES = ['none', 'bearer', 'basic', 'api_key'];
const NO_AUTH = { type: 'none' };
export const EVERY_ITEM = '*';
const KEY_LENGTH = 32;
const PLAIN_PATH_KEY = /^[A-Za-z0-9_$-]+$/;

export const toKey = text =>
  String(text)
    .toLowerCase()
    .replace(/[^a-z0-9_]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, KEY_LENGTH) || 'value';

export const uniqueKey = (text, takenKeys) => {
  const base = toKey(text);
  let key = base;
  let counter = 2;
  while (takenKeys.includes(key)) {
    const suffix = `_${counter}`;
    key = `${base.slice(0, KEY_LENGTH - suffix.length)}${suffix}`;
    counter += 1;
  }
  return key;
};

export const canAddStep = (type, steps) =>
  steps.filter(step => step.type === type).length < MAX_STEPS[type];

export const newStep = (type, steps) => {
  const keys = steps.map(step => step.key);
  if (type === 'verify') {
    return {
      key: uniqueKey('check', keys),
      type: 'verify',
      left: '',
      right: '',
      compare: 'exact',
      require_verified_contact: false,
      failure_message: '',
    };
  }
  // A new request reuses the auth of the first request that has one.
  const withAuth = steps.find(
    step =>
      step.type === 'request' && step.auth?.type && step.auth.type !== 'none'
  );
  return {
    key: uniqueKey('request', keys),
    type: 'request',
    method: 'GET',
    url: '',
    headers: [],
    body_type: 'json',
    body: '',
    auth: withAuth ? { same_as: withAuth.key } : { ...NO_AUTH },
    auth_configured: false,
  };
};

// A request can only reuse the auth of a request before it; after a move or removal any other falls back to none.
const fixSameAs = steps =>
  steps.map((step, index) => {
    const sameAs = step.auth?.same_as;
    if (!sameAs) return step;
    const earlier = steps.slice(0, index).some(other => other.key === sameAs);
    return earlier ? step : { ...step, auth: { ...NO_AUTH } };
  });

export const moveStep = (steps, index, offset) => {
  const target = index + offset;
  if (target < 0 || target >= steps.length) return steps;
  const moved = [...steps];
  [moved[index], moved[target]] = [moved[target], moved[index]];
  return fixSameAs(moved);
};

// Removing a step also removes the outputs saved from its response.
export const removeStep = (steps, outputs, index) => {
  const { key } = steps[index];
  return {
    steps: fixSameAs(steps.filter((_, position) => position !== index)),
    outputs: outputs.filter(output => output.step !== key),
  };
};

// The earlier requests a step can reuse the auth of, numbered as in the step list.
export const sameAsOptions = (steps, index) =>
  steps
    .slice(0, index)
    .map((step, position) => ({ step, number: position + 1 }))
    .filter(({ step }) => step.type === 'request' && !step.auth?.same_as)
    .map(({ step, number }) => ({ key: step.key, number }));

// What a step's templates may read: inputs, outputs of earlier steps and a few contact fields.
export const variablesBefore = (
  { param_schema: params, steps, outputs },
  index
) => {
  const earlierSteps = steps.slice(0, index).map(step => step.key);
  return {
    inputs: params.filter(param => param.name).map(param => param.name),
    outputs: outputs
      .filter(output => earlierSteps.includes(output.step))
      .map(output => `outputs.${output.key}`),
    contact: CONTACT_FIELDS.map(field => `contact.${field}`),
  };
};

// Splits a template into text and {{ variable }} parts so summaries can show variables as tags.
export const templateParts = text =>
  String(text || '')
    .split(/({{[^}]*}})/)
    .filter(Boolean)
    .map(part => {
      const variable = part.match(/^{{\s*([^}]*?)\s*}}$/);
      return variable ? { variable: variable[1] } : { text: part };
    });

export const pathFromSegments = segments =>
  segments
    .map((segment, position) => {
      if (segment === EVERY_ITEM) return '[*]';
      if (typeof segment === 'number') return `[${segment}]`;
      if (PLAIN_PATH_KEY.test(segment))
        return position === 0 ? segment : `.${segment}`;
      return `["${segment.replace(/["\\]/g, '\\$&')}"]`;
    })
    .join('');

export const lastIndexPosition = segments =>
  segments.findLastIndex(segment => typeof segment === 'number');

// "Every item" replaces the last array index with [*], so the output holds that field of each item.
export const everyItemSegments = segments => {
  const position = lastIndexPosition(segments);
  return segments.map((segment, index) =>
    index === position ? EVERY_ITEM : segment
  );
};

export const inferType = value => {
  if (Array.isArray(value)) return 'array';
  if (value !== null && typeof value === 'object') return 'object';
  if (typeof value === 'number' || typeof value === 'boolean')
    return typeof value;
  return 'string';
};

export const outputFromPick = ({ stepKey, segments, value }, outputs) => {
  const name = [...segments]
    .reverse()
    .find(segment => typeof segment === 'string' && segment !== EVERY_ITEM);
  return {
    key: uniqueKey(
      name || stepKey,
      outputs.map(output => output.key)
    ),
    step: stepKey,
    path: pathFromSegments(segments),
    type: segments.includes(EVERY_ITEM) ? 'array' : inferType(value),
    available_to_ai: true,
    required: false,
  };
};

// Steps saved before auth moved into each request use the action's auth: the first request shows it, later
// ones reuse the first.
const requestAuth = (step, tool, firstRequestKey) => {
  if (step.auth) return { ...NO_AUTH, ...step.auth };
  const type = tool.auth_type || 'none';
  if (step.key !== firstRequestKey)
    return type === 'none' ? { ...NO_AUTH } : { same_as: firstRequestKey };
  return {
    type,
    username: tool.auth_config?.username || '',
    name: tool.auth_config?.name || '',
  };
};

export const fromTool = (tool = {}) => {
  const steps = tool.steps || [];
  const firstRequestKey = steps.find(step => step.type === 'request')?.key;
  return {
    title: tool.title || '',
    description: tool.description || '',
    param_schema: (tool.param_schema || []).map(param => ({
      test_value: '',
      ...param,
    })),
    steps: steps.map(step =>
      step.type === 'request'
        ? {
            headers: [],
            body: '',
            ...step,
            auth: requestAuth(step, tool, firstRequestKey),
            auth_configured: !!step.auth_configured,
          }
        : { failure_message: '', ...step }
    ),
    outputs: (tool.outputs || []).map(output => ({ ...output })),
    execution_mode: tool.execution_mode || 'background',
    messages: {
      confirm_prompt: '',
      success: '',
      failure: '',
      ...tool.messages,
    },
    response_template: tool.response_template || '',
  };
};

// Only the fields of the chosen auth type are sent. Blank secrets are left out so the saved ones stay.
const AUTH_FIELDS = {
  none: [],
  bearer: ['token'],
  basic: ['username', 'password'],
  api_key: ['name', 'key'],
};
const authPayload = auth => {
  if (auth.same_as) return { same_as: auth.same_as };
  const fields = AUTH_FIELDS[auth.type] || [];
  return {
    type: auth.type,
    ...Object.fromEntries(
      fields
        .filter(field => !SECRET_AUTH_KEYS.includes(field) || auth[field])
        .map(field => [field, auth[field] || ''])
    ),
  };
};

// Blank messages are left out so the defaults apply.
export const toPayload = form => ({
  title: form.title,
  description: form.description,
  param_schema: form.param_schema.map(param => ({
    ...param,
    test_value: String(param.test_value ?? ''),
  })),
  steps: form.steps.map(step => {
    if (step.type !== 'request') return step;
    const request = { ...step };
    delete request.auth_configured;
    return {
      ...request,
      headers: step.headers.filter(header => header.name),
      auth: authPayload(step.auth),
    };
  }),
  outputs: form.outputs,
  execution_mode: form.execution_mode,
  messages: Object.fromEntries(
    Object.entries(form.messages).filter(([, value]) => value)
  ),
  response_template: form.response_template,
});
