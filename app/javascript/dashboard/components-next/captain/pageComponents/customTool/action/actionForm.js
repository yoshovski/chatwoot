// Form helpers for the action page: step list edits, the variables a step may use, and outputs saved by clicking
// a value in a test response. Paths match the backend's Captain::Tools::ResponsePath syntax.
export const MAX_STEPS = { request: 3, verify: 2 };
export const REQUEST_METHODS = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];
export const COMPARISONS = ['exact', 'case_insensitive', 'email', 'phone'];
export const CONTACT_FIELDS = ['email', 'phone_number', 'name'];
export const OUTPUT_TYPES = ['string', 'number', 'boolean', 'array', 'object'];
export const SECRET_AUTH_KEYS = ['token', 'password', 'key'];
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
    };
  }
  return {
    key: uniqueKey('request', keys),
    type: 'request',
    method: 'GET',
    url: '',
    headers: [],
    body_type: 'json',
    body: '',
  };
};

export const moveStep = (steps, index, offset) => {
  const target = index + offset;
  if (target < 0 || target >= steps.length) return steps;
  const moved = [...steps];
  [moved[index], moved[target]] = [moved[target], moved[index]];
  return moved;
};

// Removing a step also removes the outputs saved from its response.
export const removeStep = (steps, outputs, index) => {
  const { key } = steps[index];
  return {
    steps: steps.filter((_, position) => position !== index),
    outputs: outputs.filter(output => output.step !== key),
  };
};

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

export const fromTool = (tool = {}) => ({
  title: tool.title || '',
  description: tool.description || '',
  auth_type: tool.auth_type || 'none',
  auth_config: { ...(tool.auth_config || {}) },
  auth_configured: !!tool.auth_configured,
  param_schema: (tool.param_schema || []).map(param => ({
    test_value: '',
    ...param,
  })),
  steps: (tool.steps || []).map(step =>
    step.type === 'request' ? { headers: [], body: '', ...step } : { ...step }
  ),
  outputs: (tool.outputs || []).map(output => ({ ...output })),
  execution_mode: tool.execution_mode || 'background',
  messages: { confirm_prompt: '', success: '', failure: '', ...tool.messages },
  response_template: tool.response_template || '',
});

// Blank secrets are left out so the saved ones stay; blank messages are left out so defaults apply.
export const toPayload = form => {
  const authConfig = Object.fromEntries(
    Object.entries(form.auth_config).filter(
      ([key, value]) => !SECRET_AUTH_KEYS.includes(key) || value
    )
  );
  return {
    title: form.title,
    description: form.description,
    auth_type: form.auth_type,
    auth_config: authConfig,
    param_schema: form.param_schema.map(param => ({
      ...param,
      test_value: String(param.test_value ?? ''),
    })),
    steps: form.steps.map(step =>
      step.type === 'request'
        ? {
            ...step,
            headers: step.headers.filter(header => header.name),
          }
        : step
    ),
    outputs: form.outputs,
    execution_mode: form.execution_mode,
    messages: Object.fromEntries(
      Object.entries(form.messages).filter(([, value]) => value)
    ),
    response_template: form.response_template,
  };
};
