// Scenario templates. UI copy (titles, questions, options) lives in en.json under
// CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES; the instruction text written by `build`
// is for the model and stays here in English, the merchant edits it on the preview step.

// What each selectable field asks the customer for, as written into the steps.
const FIELD_PROMPTS = {
  products_and_quantities: 'Exact products and quantities',
  variant_or_specs: 'Variant, size or technical specs',
  customisation: 'Customisation or branding (logo, engraving, packaging)',
  recurring: "Whether it's a one-off or a recurring order",
  delivery_country_postcode: 'Delivery country and postcode',
  needed_by: 'Date they need it by',
  delivery_address: 'Full delivery or installation address',
  shipping_preference: 'Shipping preference (standard, express or pickup)',
  name_and_email: 'Name and email address',
  phone: 'Phone number',
  company_name: 'Company name',
  vat_id: 'VAT or tax ID',
  country: 'Country',
  website: 'Company website',
  contact_person: 'Contact person',
  resale_or_own_use: 'Whether they resell the products or use them themselves',
  products_and_volume: 'Products of interest and expected volume',
  budget: 'Budget or target price',
  intended_use: 'Intended use',
  files: 'Files, drawings or photos (they can attach them in the chat)',
  existing_customer: 'Existing customer or order number',
  payment_terms: 'Preferred payment terms',
  order_number: 'Order number',
  checkout_email: 'Email address used at checkout',
  product: 'Which product it is about',
  reason: 'Reason for the return or a description of the defect',
  photos: 'Photos or a short video of the problem',
  serial_number: 'Serial number',
  date_received: 'Date they received it',
  condition: 'Whether the item is unused or has been used',
  preferred_outcome: 'Preferred outcome (refund, replacement or repair)',
  topic: 'What they want to talk about',
  preferred_time: 'Preferred day and time zone',
  main_use: 'Main use or goal',
  experience_level: 'Experience level',
  compatibility: 'Model or equipment it must be compatible with',
  must_have_features: 'Must-have features',
  product_demo: 'a product demo',
  advice_before_buying: 'advice before buying',
  technical_help: 'technical help',
  partnerships: 'partnerships',
  customer_asks: 'The customer asks for a call or a meeting',
  unanswered_technical:
    "A technical question that the knowledge sources can't answer",
  large_order: 'A large or custom order',
};

const REPLY_TIMES = {
  within_1_business_day: 'within 1 business day',
  within_24_hours: 'within 24 hours',
  within_2_3_business_days: 'within 2–3 business days',
};

const COMMON_RULES = [
  'Ask one question at a time and only for details that are still missing.',
  'Take what the customer already said as given; a stated budget is the budget.',
  "If the customer doesn't want to give an optional detail, continue without it.",
  "Never promise prices, stock, delivery dates, refunds or discounts that a tool didn't confirm.",
];

export const MAX_CUSTOM_ENTRIES = 5;
export const CUSTOM_ENTRY_MAX_LENGTH = 60;

export const resolveToolLink = (toolId, defaultTitle, availableTools = []) => {
  const found = availableTools.find(tool => tool.id === toolId);
  return found ? `[@${found.title}](tool://${toolId})` : defaultTitle;
};

const toolLinks = tools => ({
  findProducts: resolveToolLink(
    'catalog_product_search',
    'Find products',
    tools
  ),
  searchKnowledge: resolveToolLink('faq_lookup', 'Search knowledge', tools),
  trackOrder: resolveToolLink('track_order', 'Track an order', tools),
  privateNote: resolveToolLink('add_private_note', 'Add a private note', tools),
  addLabel: resolveToolLink('add_label_to_conversation', 'Add a label', tools),
  handoff: resolveToolLink('handoff', 'Hand off to a person', tools),
});

// Predefined fields are stored by value, custom ones as { custom: true, label }.
const fieldText = field => (field.custom ? field.label : FIELD_PROMPTS[field]);

const bulletList = fields =>
  fields.map(field => `\n   - ${fieldText(field)}`).join('');

const inlineList = fields => fields.map(fieldText).join(', ');

// Predefined fields follow the group order; custom ones are asked last.
const orderedFields = (question, selected) => [
  ...question.groups
    .flatMap(group => group.options)
    .filter(value => selected.includes(value)),
  ...selected.filter(field => field.custom),
];

const buildInstruction = (intro, steps) =>
  [
    intro,
    steps.map((step, index) => `${index + 1}. ${step}`).join('\n'),
    `Rules:\n${COMMON_RULES.map(rule => `- ${rule}`).join('\n')}`,
  ].join('\n\n');

const replyTimeText = answers =>
  answers.reply_time === 'other'
    ? answers.reply_time_other.trim() || REPLY_TIMES.within_1_business_day
    : REPLY_TIMES[answers.reply_time];

const labelQuestion = defaultLabel => ({
  key: 'label',
  type: 'label',
  required: true,
  default: defaultLabel,
});

const replyTimeQuestion = {
  key: 'reply_time',
  type: 'select',
  options: [...Object.keys(REPLY_TIMES), 'other'],
  otherKey: 'reply_time_other',
  default: 'within_1_business_day',
};

export const SCENARIO_TEMPLATES = [
  {
    id: 'request_a_quote',
    icon: 'i-lucide-receipt-text',
    color: 'amber',
    requiredTools: [],
    questions: [
      { key: 'quotes_for', type: 'text', default: '' },
      {
        key: 'details',
        type: 'chips',
        allowCustom: true,
        required: true,
        default: [
          'products_and_quantities',
          'delivery_country_postcode',
          'needed_by',
          'name_and_email',
        ],
        groups: [
          {
            key: 'order',
            options: [
              'products_and_quantities',
              'variant_or_specs',
              'customisation',
              'recurring',
            ],
          },
          {
            key: 'delivery',
            options: [
              'delivery_country_postcode',
              'needed_by',
              'delivery_address',
              'shipping_preference',
            ],
          },
          {
            key: 'contact_and_company',
            options: ['name_and_email', 'phone', 'company_name', 'vat_id'],
          },
          {
            key: 'extra',
            options: [
              'budget',
              'intended_use',
              'files',
              'existing_customer',
              'payment_terms',
            ],
          },
        ],
      },
      { key: 'min_quantity', type: 'number', default: '' },
      replyTimeQuestion,
      {
        key: 'after_summary',
        type: 'select',
        options: ['handoff', 'note_only'],
        default: 'handoff',
      },
      labelQuestion('quote'),
    ],
    build(answers, tools) {
      const links = toolLinks(tools);
      const details = orderedFields(this.questions[1], answers.details);
      const quotesFor = answers.quotes_for.trim();
      const replyTime = replyTimeText(answers);
      const steps = [
        `Collect these details:${bulletList(details)}`,
        `Confirm the exact products with ${links.findProducts}.`,
        `Answer side questions about products, delivery or policies with ${links.searchKnowledge}.`,
      ];
      if (answers.min_quantity) {
        steps.push(
          `Quotes start at ${answers.min_quantity} units. Below that, say so and point to the product page to order directly.`
        );
      }
      steps.push(
        "Don't pass a quote on without the products, the quantities and a way to reach the customer.",
        'Summarise the request in a short list and ask the customer to confirm it.',
        `Once confirmed, save the summary with ${links.privateNote}.`,
        `Add the label "${answers.label}" with ${links.addLabel}.`,
        answers.after_summary === 'note_only'
          ? `Tell the customer the team will send the quote by email ${replyTime}. Don't hand the chat off.`
          : `Hand the chat to the team with ${links.handoff} and tell the customer a colleague prepares the quote ${replyTime}.`
      );

      return {
        title: 'Request a quote',
        description:
          'Use when the customer asks for a quote, bulk or volume pricing, or a price for a custom order.',
        instruction: buildInstruction(
          quotesFor
            ? `Use this when a customer asks for a quote, usually for ${quotesFor}.`
            : 'Use this when a customer asks for a quote.',
          steps
        ),
      };
    },
  },
  {
    id: 'book_a_call',
    icon: 'i-lucide-calendar-clock',
    color: 'iris',
    requiredTools: [],
    questions: [
      { key: 'booking_url', type: 'url', required: true, default: '' },
      {
        key: 'call_purposes',
        type: 'chips',
        allowCustom: true,
        required: true,
        default: ['product_demo', 'advice_before_buying'],
        groups: [
          {
            key: 'topics',
            options: [
              'product_demo',
              'advice_before_buying',
              'technical_help',
              'partnerships',
            ],
          },
        ],
      },
      {
        key: 'offer_when',
        type: 'chips',
        allowCustom: true,
        required: true,
        default: ['customer_asks'],
        groups: [
          {
            key: 'situations',
            options: ['customer_asks', 'unanswered_technical', 'large_order'],
          },
        ],
      },
      {
        key: 'ask_first',
        type: 'chips',
        allowCustom: true,
        default: ['topic'],
        groups: [
          {
            key: 'contact',
            options: ['topic', 'name_and_email', 'phone', 'preferred_time'],
          },
        ],
      },
      labelQuestion('call'),
    ],
    build(answers, tools) {
      const links = toolLinks(tools);
      const [, purposesQuestion, offerQuestion, askQuestion] = this.questions;
      const purposes = orderedFields(purposesQuestion, answers.call_purposes);
      const askFirst = orderedFields(askQuestion, answers.ask_first);
      const steps = [
        `Offer a call when:${bulletList(orderedFields(offerQuestion, answers.offer_when))}`,
      ];
      if (askFirst.length) {
        steps.push(`Before sharing the link, ask for:${bulletList(askFirst)}`);
      }
      steps.push(
        `Share the booking link as [Book a call](${answers.booking_url}) with one sentence on what the call covers. Calls are for ${inlineList(purposes)}.`,
        `Add the label "${answers.label}" with ${links.addLabel}.`,
        'Never promise a time slot; the customer picks one on the booking page.',
        `If no slot suits them, hand the chat to the team with ${links.handoff}.`
      );

      return {
        title: 'Book a call',
        description:
          'Use when the customer wants to talk to someone, asks for a call, a meeting or a product demo.',
        instruction: buildInstruction(
          'Use this when a call is the best next step for the customer.',
          steps
        ),
      };
    },
  },
  {
    id: 'returns_and_warranty',
    icon: 'i-lucide-undo-2',
    color: 'teal',
    requiredTools: [],
    questions: [
      { key: 'return_window', type: 'number', required: true, default: 30 },
      {
        key: 'warranty_period',
        type: 'text',
        required: true,
        default: '2 years',
      },
      {
        key: 'details',
        type: 'chips',
        allowCustom: true,
        required: true,
        default: [
          'order_number',
          'checkout_email',
          'product',
          'reason',
          'photos',
        ],
        groups: [
          {
            key: 'order',
            options: ['order_number', 'checkout_email', 'product'],
          },
          {
            key: 'problem',
            options: [
              'reason',
              'photos',
              'serial_number',
              'date_received',
              'condition',
            ],
          },
          { key: 'outcome', options: ['preferred_outcome'] },
        ],
      },
      labelQuestion('return'),
    ],
    build(answers, tools) {
      const links = toolLinks(tools);
      const details = orderedFields(this.questions[2], answers.details);
      const steps = [
        `Find out whether it's a return within the ${answers.return_window}-day return window or a defect covered by the ${answers.warranty_period} warranty.`,
        `Collect these details:${bulletList(details)}`,
        `Once you have the order number and email, check the order with ${links.trackOrder}.`,
        `Check the return and warranty policy with ${links.searchKnowledge} and explain only what applies to this case.`,
        'Never promise a refund, replacement or timeline before the team has reviewed the claim.',
        `Save a summary of the claim with ${links.privateNote}.`,
        `Add the label "${answers.label}" with ${links.addLabel}.`,
        `Hand the chat to the team with ${links.handoff} and tell the customer the team reviews the claim.`,
      ];

      return {
        title: 'Returns and warranty',
        description:
          'Use when the customer wants to return or exchange an item, or reports a damaged or defective product.',
        instruction: buildInstruction(
          'Use this for returns, exchanges and warranty claims.',
          steps
        ),
      };
    },
  },
  {
    id: 'product_finder',
    icon: 'i-lucide-compass',
    color: 'ruby',
    requiredTools: ['catalog_product_search'],
    questions: [
      { key: 'category', type: 'text', default: '' },
      {
        key: 'questions_to_ask',
        type: 'chips',
        allowCustom: true,
        required: true,
        default: ['budget', 'main_use'],
        groups: [
          {
            key: 'needs',
            options: [
              'budget',
              'main_use',
              'experience_level',
              'compatibility',
              'must_have_features',
            ],
          },
        ],
      },
      {
        key: 'recommendation_count',
        type: 'select',
        options: ['1', '2', '3'],
        default: '2',
      },
    ],
    build(answers, tools) {
      const links = toolLinks(tools);
      const toAsk = orderedFields(this.questions[1], answers.questions_to_ask);
      const category = answers.category.trim();
      const steps = [
        `Ask up to 3 short questions, one at a time, and skip what the customer already said:${bulletList(toAsk)}`,
        'Offer answer buttons when the options are clear.',
        `Search with ${links.findProducts} using their needs as keywords.`,
        `Recommend the best ${answers.recommendation_count}, each with one reason tied to their answers. Product cards show automatically.`,
        `Answer spec and compatibility questions with ${links.searchKnowledge}. Never invent specs.`,
        `If nothing fits, say so and offer the closest option, or hand off with ${links.handoff}.`,
      ];

      return {
        title: 'Product finder',
        description:
          'Use when the customer needs help choosing a product, asks for a recommendation or compares options.',
        instruction: buildInstruction(
          category
            ? `Use this to help customers choose ${category}.`
            : 'Use this to help customers choose the right product.',
          steps
        ),
      };
    },
  },
  {
    id: 'b2b_inquiry',
    icon: 'i-lucide-building-2',
    color: 'slate',
    requiredTools: [],
    questions: [
      {
        key: 'qualification',
        type: 'text',
        required: true,
        default: 'companies, resellers or orders above 20 units',
      },
      {
        key: 'details',
        type: 'chips',
        allowCustom: true,
        required: true,
        default: ['company_name', 'vat_id', 'country', 'products_and_volume'],
        groups: [
          {
            key: 'company',
            options: ['company_name', 'vat_id', 'country', 'website'],
          },
          {
            key: 'order',
            options: ['products_and_volume', 'recurring', 'resale_or_own_use'],
          },
          { key: 'contact', options: ['contact_person', 'phone'] },
        ],
      },
      replyTimeQuestion,
      labelQuestion('b2b'),
    ],
    build(answers, tools) {
      const links = toolLinks(tools);
      const details = orderedFields(this.questions[1], answers.details);
      const steps = [
        `Treat ${answers.qualification} as business customers.`,
        `Collect these details:${bulletList(details)}`,
        'Never quote wholesale prices, contract terms or discounts in the chat.',
        `Save a summary of the company and the request with ${links.privateNote}.`,
        `Add the label "${answers.label}" with ${links.addLabel}.`,
        `Hand the chat to the team with ${links.handoff} and tell the customer the team replies ${replyTimeText(answers)}.`,
      ];

      return {
        title: 'B2B and wholesale',
        description:
          'Use when a company or reseller asks about wholesale prices, bulk purchases, resale or distributor terms.',
        instruction: buildInstruction(
          'Use this for business and wholesale inquiries.',
          steps
        ),
      };
    },
  },
];

export const getTemplateById = id =>
  SCENARIO_TEMPLATES.find(template => template.id === id);

export const defaultAnswers = template =>
  Object.fromEntries(
    template.questions.flatMap(question => [
      [
        question.key,
        Array.isArray(question.default)
          ? [...question.default]
          : question.default,
      ],
      ...(question.otherKey ? [[question.otherKey, '']] : []),
    ])
  );

export const buildFromTemplate = (template, answers = {}, tools = []) =>
  template.build({ ...defaultAnswers(template), ...answers }, tools);

export const countSteps = instruction =>
  (instruction.match(/^\d+\.\s/gm) || []).length;

export const isTemplateAvailable = (template, tools = []) =>
  template.requiredTools.every(toolId =>
    tools.some(tool => tool.id === toolId)
  );

// Mirrors Captain::Conversation::ReplySanitizer#url_matches_pattern? so the
// stepper asks only when a reply link would really be stripped.
export const isLinkAllowed = (url, allowlist = []) => {
  const target = url.trim().toLowerCase();
  return allowlist.some(entry => {
    const pattern = entry.trim().toLowerCase();
    if (!pattern) return false;
    if (target === pattern || target === pattern.replace(/\/$/, '')) {
      return true;
    }
    if (pattern.endsWith('/')) return target.startsWith(pattern);
    return (
      target.startsWith(`${pattern}/`) ||
      (!pattern.includes('?') && target.startsWith(`${pattern}?`))
    );
  });
};

export const allowlistEntryFor = url => `${new URL(url).origin}/`;
