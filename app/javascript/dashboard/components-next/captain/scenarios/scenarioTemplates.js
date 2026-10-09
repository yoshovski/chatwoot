export const resolveToolLink = (toolId, defaultTitle, availableTools = []) => {
  const found = (availableTools || []).find(tool => {
    if (typeof tool === 'string') return tool === toolId;
    return tool?.id === toolId;
  });
  if (found) {
    const title =
      typeof found === 'object' && found.title ? found.title : defaultTitle;
    return `[@${title}](tool://${toolId})`;
  }
  return defaultTitle;
};

export const SCENARIO_TEMPLATES = [
  {
    id: 'request_a_quote',
    emoji: '🧾',
    color: 'amber',
    title: 'Request a quote',
    tagline:
      'Collect requirements and prepare custom quotes for your sales team',
    requiredTools: [],
    demo: [
      {
        role: 'customer',
        text: 'Hi! Can I get a quote for 25 units of Model X200?',
      },
      { role: 'typing' },
      {
        role: 'assistant',
        text: 'I would be happy to help with a quote! What is your delivery country or postal code?',
      },
      { role: 'customer', text: 'Germany, postal code 10115.' },
      { role: 'typing' },
      {
        role: 'assistant',
        text: 'Thank you! Do you have a target delivery date or deadline for this order?',
      },
      { role: 'customer', text: 'End of next month.' },
      { role: 'typing' },
      {
        role: 'assistant',
        text: 'Summary: 25x Model X200 for delivery to Germany (10115) by end of next month. Does everything look correct?',
        action: {
          type: 'note',
          text: 'Private note: 25x Model X200, Germany (10115)',
        },
        handoff:
          'Passing to our sales team to prepare your official quote within 24 hours',
      },
    ],
    questions: [
      {
        key: 'quotes_for',
        type: 'text',
        label: 'What are quotes usually requested for?',
        helperText: 'Helps the assistant understand what can be quoted.',
        placeholder: 'e.g. bulk orders or custom specifications',
        default: 'bulk orders or custom specifications',
        required: false,
      },
      {
        key: 'details_to_collect',
        type: 'chips',
        label: 'What details should be collected from the customer?',
        helperText:
          'The assistant asks for these one by one before submitting.',
        default: [
          'products_and_quantities',
          'delivery_country_or_postcode',
          'deadline',
        ],
        options: [
          {
            value: 'products_and_quantities',
            label: 'Products and quantities',
          },
          {
            value: 'delivery_country_or_postcode',
            label: 'Delivery country or postcode',
          },
          { value: 'deadline', label: 'Target deadline' },
          { value: 'budget', label: 'Budget' },
          { value: 'company_and_vat', label: 'Company and VAT number' },
          { value: 'intended_use', label: 'Intended use' },
        ],
      },
      {
        key: 'min_quantity',
        type: 'number',
        label: 'Minimum quantity for a quote (optional)',
        helperText:
          'Below this quantity, the assistant refers to standard store pricing.',
        placeholder: 'e.g. 10',
        default: null,
        required: false,
      },
      {
        key: 'label',
        type: 'text',
        label: 'Conversation tag / label',
        helperText: 'Applied when handing off to the team.',
        placeholder: 'quote',
        default: 'quote',
        required: true,
      },
      {
        key: 'reply_time',
        type: 'text',
        label: 'Follow-up timeline promise',
        helperText:
          'Estimated time before your team follows up with the quote.',
        placeholder: 'within 24 hours',
        default: 'within 24 hours',
        required: false,
      },
    ],
    build(answers = {}, tools = []) {
      const quoteTarget =
        answers.quotes_for || 'bulk orders or custom specifications';
      const details = answers.details_to_collect || [
        'products_and_quantities',
        'delivery_country_or_postcode',
        'deadline',
      ];
      const minQty = answers.min_quantity;
      const label = answers.label || 'quote';
      const replyTime = answers.reply_time || 'within 24 hours';

      const findProducts = resolveToolLink(
        'catalog_product_search',
        'Find products',
        tools
      );
      const searchKnowledge = resolveToolLink(
        'faq_lookup',
        'Search knowledge',
        tools
      );
      const privateNote = resolveToolLink(
        'add_private_note',
        'Add a private note',
        tools
      );
      const addLabel = resolveToolLink(
        'add_label_to_conversation',
        'Add a label',
        tools
      );
      const handoff = resolveToolLink('handoff', 'Hand off to a person', tools);

      let instruction = `When a customer asks for a quote for ${quoteTarget}, guide them through the quote request:\n\n`;
      instruction += `1. Collect the following details one at a time, asking only for information not already provided:\n`;
      if (details.includes('products_and_quantities'))
        instruction += `   - Exact products and quantities\n`;
      if (details.includes('delivery_country_or_postcode'))
        instruction += `   - Delivery country or postal code\n`;
      if (details.includes('deadline'))
        instruction += `   - Target deadline or required delivery date\n`;
      if (details.includes('budget'))
        instruction += `   - Budget or target price\n`;
      if (details.includes('company_and_vat'))
        instruction += `   - Company name and VAT / tax number\n`;
      if (details.includes('intended_use'))
        instruction += `   - Intended use or project requirements\n`;

      instruction += `2. Confirm the exact items requested using ${findProducts}.\n`;
      instruction += `3. Answer any product or specification questions using ${searchKnowledge}.\n`;
      if (minQty) {
        instruction += `4. If the requested quantity is below ${minQty} units, let them know our minimum for custom quotes is ${minQty} and invite them to order directly through the store.\n`;
      }
      instruction += `5. Summarise the collected quote details and ask the customer to confirm them.\n`;
      instruction += `6. Once confirmed, leave an internal summary using ${privateNote}.\n`;
      instruction += `7. Tag the conversation with "${label}" using ${addLabel}.\n`;
      instruction += `8. Use ${handoff} to transfer the conversation to the team, assuring the customer that a colleague will prepare the quote ${replyTime}.`;

      const description =
        'Use when the customer asks for a quote, bulk pricing, or custom order estimates.';

      return {
        title: 'Request a quote',
        description,
        instruction,
      };
    },
  },
  {
    id: 'book_a_call',
    emoji: '📅',
    color: 'iris',
    title: 'Book a call',
    tagline:
      'Let customers schedule a call or product demo through your booking link',
    requiredTools: [],
    demo: [
      {
        role: 'customer',
        text: 'Can someone on your team jump on a quick call with me?',
      },
      { role: 'typing' },
      {
        role: 'assistant',
        text: 'We would love to speak with you! What topic would you like to cover during the call?',
      },
      {
        role: 'customer',
        text: 'A technical demo of your enterprise features.',
      },
      { role: 'typing' },
      {
        role: 'assistant',
        text: 'You can pick a convenient slot directly on our calendar: [Schedule a demo](https://cal.com/demo).',
        buttons: ['Schedule a demo (Cal.com)'],
      },
    ],
    questions: [
      {
        key: 'booking_url',
        type: 'url',
        label: 'Booking page URL',
        helperText: 'Cal.com, Calendly or custom booking link (https://).',
        placeholder: 'https://cal.com/your-team/intro',
        default: 'https://cal.com/team/demo',
        required: true,
      },
      {
        key: 'call_purposes',
        type: 'chips',
        label: 'What are calls offered for?',
        helperText: 'Topics covered during the scheduled call.',
        default: ['product_demo', 'advice_before_buying'],
        options: [
          { value: 'product_demo', label: 'Product demo' },
          { value: 'advice_before_buying', label: 'Advice before buying' },
          { value: 'technical_help', label: 'Technical help' },
          { value: 'partnerships', label: 'Partnerships' },
        ],
      },
      {
        key: 'trigger_conditions',
        type: 'chips',
        label: 'When to offer a call',
        helperText: 'Situations that prompt suggesting a call.',
        default: ['customer_asks'],
        options: [
          { value: 'customer_asks', label: 'Customer asks for a call' },
          {
            value: 'technical_question_unanswered',
            label: 'Technical question unanswered by knowledge',
          },
          {
            value: 'large_or_custom_order',
            label: 'Large or custom order inquiry',
          },
        ],
      },
      {
        key: 'ask_first',
        type: 'chips',
        label: 'What to ask before sharing the link',
        default: ['topic'],
        options: [
          { value: 'topic', label: 'Call topic / goal' },
          { value: 'name', label: 'Customer name' },
          { value: 'email', label: 'Email address' },
        ],
      },
      {
        key: 'label',
        type: 'text',
        label: 'Conversation tag / label',
        default: 'call',
        required: true,
      },
    ],
    build(answers = {}, tools = []) {
      const bookingUrl = answers.booking_url || 'https://cal.com/team/demo';
      const label = answers.label || 'call';
      const askFirst = answers.ask_first || ['topic'];

      const addLabel = resolveToolLink(
        'add_label_to_conversation',
        'Add a label',
        tools
      );
      const handoff = resolveToolLink('handoff', 'Hand off to a person', tools);

      let instruction = `When a customer wants to schedule or book a call:\n\n`;
      if (askFirst.includes('topic')) {
        instruction += `1. If the goal or topic of the call is not yet clear, ask what they would like to discuss before sharing the booking link.\n`;
      }
      if (askFirst.includes('name') || askFirst.includes('email')) {
        instruction += `2. Confirm their contact information if missing.\n`;
      }
      instruction += `3. Share the scheduling link: [Schedule a call](${bookingUrl}) with a brief sentence explaining what the call covers.\n`;
      instruction += `4. Tag the conversation with "${label}" using ${addLabel}.\n`;
      instruction += `5. Never promise a specific date or time slot in the chat; advise them to select an open slot on the booking calendar.\n`;
      instruction += `6. If none of the available calendar times work for them, pass the conversation to the team using ${handoff}.`;

      const description =
        'Use when a customer wants to schedule a call, consultation, or product demonstration.';

      return {
        title: 'Book a call',
        description,
        instruction,
      };
    },
  },
  {
    id: 'returns_and_warranty',
    emoji: '↩️',
    color: 'teal',
    title: 'Returns & warranty claim',
    tagline: 'Handle standard returns and warranty defect claims step by step',
    requiredTools: [],
    demo: [
      {
        role: 'customer',
        text: 'My Model X200 battery stopped charging after 3 weeks. Order #1001.',
      },
      { role: 'typing' },
      {
        role: 'assistant',
        text: 'I am sorry to hear that. I checked order #1001 — it is within your 2-year warranty window. Could you share a quick photo showing the issue?',
      },
      { role: 'customer', text: 'Uploaded photo: charger_error.jpg' },
      { role: 'typing' },
      {
        role: 'assistant',
        text: 'Thank you for the photo! I have logged your warranty claim with our team.',
        action: {
          type: 'note',
          text: 'Claim summary: Order #1001, defect verified with photo',
        },
        handoff: 'Passing to our warranty team for replacement authorization',
      },
    ],
    questions: [
      {
        key: 'return_window',
        type: 'number',
        label: 'Return window (days)',
        helperText: 'Number of days customers can return for refund/exchange.',
        default: 30,
        required: true,
      },
      {
        key: 'warranty_period',
        type: 'text',
        label: 'Warranty period',
        helperText: 'Duration covered for defective or broken items.',
        default: '2 years',
        required: true,
      },
      {
        key: 'details_to_collect',
        type: 'chips',
        label: 'What to collect',
        default: [
          'order_number',
          'checkout_email',
          'product_and_reason',
          'photos_of_problem',
        ],
        options: [
          { value: 'order_number', label: 'Order number' },
          { value: 'checkout_email', label: 'Checkout email' },
          { value: 'product_and_reason', label: 'Product and reason' },
          { value: 'photos_of_problem', label: 'Photos of the problem' },
          { value: 'serial_number', label: 'Serial number' },
        ],
      },
      {
        key: 'label',
        type: 'text',
        label: 'Conversation tag / label',
        default: 'return',
        required: true,
      },
    ],
    build(answers = {}, tools = []) {
      const returnWindow = answers.return_window || 30;
      const warrantyPeriod = answers.warranty_period || '2 years';
      const label = answers.label || 'return';
      const details = answers.details_to_collect || [
        'order_number',
        'checkout_email',
        'product_and_reason',
        'photos_of_problem',
      ];

      const trackOrder = resolveToolLink(
        'track_order',
        'Track an order',
        tools
      );
      const searchKnowledge = resolveToolLink(
        'faq_lookup',
        'Search knowledge',
        tools
      );
      const privateNote = resolveToolLink(
        'add_private_note',
        'Add a private note',
        tools
      );
      const addLabel = resolveToolLink(
        'add_label_to_conversation',
        'Add a label',
        tools
      );
      const handoff = resolveToolLink('handoff', 'Hand off to a person', tools);

      let instruction = `Guide the customer through return or warranty requests:\n\n`;
      instruction += `1. Clarify whether they want a standard return within the ${returnWindow}-day return window or have a defect covered by the ${warrantyPeriod} warranty.\n`;
      instruction += `2. Collect missing details one at a time:\n`;
      if (details.includes('order_number'))
        instruction += `   - Order number\n`;
      if (details.includes('checkout_email'))
        instruction += `   - Checkout email address\n`;
      if (details.includes('product_and_reason'))
        instruction += `   - Product name and reason for return or defect description\n`;
      if (details.includes('serial_number'))
        instruction += `   - Device serial number\n`;
      instruction += `3. When order number and email are provided, verify the order details using ${trackOrder}.\n`;
      instruction += `4. Check warranty and return guidelines with ${searchKnowledge} and explain only the rules that apply to their case.\n`;
      if (details.includes('photos_of_problem')) {
        instruction += `5. For broken or defective items, ask the customer to upload a clear photo of the issue.\n`;
      }
      instruction += `6. Never promise an immediate refund, replacement, or timeline before the team inspects the claim.\n`;
      instruction += `7. Add a private note summarizing the claim using ${privateNote}.\n`;
      instruction += `8. Tag the conversation with "${label}" using ${addLabel}.\n`;
      instruction += `9. Hand off to the team with ${handoff}, letting the customer know our team is reviewing the claim.`;

      const description =
        'Use when the customer wants to return an item, request a replacement, or report a damaged or defective product.';

      return {
        title: 'Returns & warranty claim',
        description,
        instruction,
      };
    },
  },
  {
    id: 'product_finder',
    emoji: '🧭',
    color: 'violet',
    title: 'Product finder',
    tagline:
      'Guide shoppers to the right product with a few targeted questions',
    requiredTools: ['catalog_product_search'],
    demo: [
      {
        role: 'customer',
        text: 'I need a portable charger for backpacking under $80.',
      },
      { role: 'typing' },
      {
        role: 'assistant',
        text: 'Here are two lightweight options that fit your backpacking budget:',
      },
      {
        role: 'assistant',
        productCard: {
          title: 'CampPower Mini 10k',
          price: '$49.00',
          feature: 'Ultralight (180g), waterproof rating IP67',
        },
      },
      {
        role: 'assistant',
        productCard: {
          title: 'TrailCharge 20k Solar',
          price: '$75.00',
          feature: 'Dual USB-C, built-in emergency solar panel',
        },
      },
      {
        role: 'customer',
        text: 'Does the CampPower Mini support USB-C PD fast charging?',
      },
      { role: 'typing' },
      {
        role: 'assistant',
        text: 'Yes! It delivers 20W USB-C Power Delivery fast charging.',
      },
    ],
    questions: [
      {
        key: 'product_category',
        type: 'text',
        label: 'What does this help customers choose?',
        placeholder: 'e.g. products from our catalog',
        default: 'products from our catalog',
        required: true,
      },
      {
        key: 'questions_to_ask',
        type: 'chips',
        label: '2–3 questions to ask the shopper',
        default: ['budget', 'main_use'],
        options: [
          { value: 'budget', label: 'Budget / price range' },
          { value: 'main_use', label: 'Main use or goal' },
          { value: 'experience_level', label: 'Experience level' },
          { value: 'compatibility', label: 'Compatibility with owned items' },
          { value: 'must_have_features', label: 'Must-have features' },
        ],
      },
      {
        key: 'recommendation_count',
        type: 'number',
        label: 'Number of recommendations (1–3)',
        default: 2,
        required: true,
      },
    ],
    build(answers = {}, tools = []) {
      const category = answers.product_category || 'products from our catalog';
      const questionsToAsk = answers.questions_to_ask || ['budget', 'main_use'];
      const count = answers.recommendation_count || 2;

      const findProducts = resolveToolLink(
        'catalog_product_search',
        'Find products',
        tools
      );
      const searchKnowledge = resolveToolLink(
        'faq_lookup',
        'Search knowledge',
        tools
      );
      const handoff = resolveToolLink('handoff', 'Hand off to a person', tools);

      let instruction = `Help customers find the best ${category} for their needs:\n\n`;
      instruction += `1. Ask up to 3 short questions one at a time to understand their preferences, skipping anything they already stated:\n`;
      if (questionsToAsk.includes('budget'))
        instruction += `   - Budget or target price\n`;
      if (questionsToAsk.includes('main_use'))
        instruction += `   - Primary use case or goal\n`;
      if (questionsToAsk.includes('experience_level'))
        instruction += `   - Experience level or familiarity\n`;
      if (questionsToAsk.includes('compatibility'))
        instruction += `   - Compatibility with existing equipment\n`;
      if (questionsToAsk.includes('must_have_features'))
        instruction += `   - Must-have features or preferences\n`;
      instruction += `2. Search our catalog using ${findProducts} using their requirements as keywords.\n`;
      instruction += `3. Recommend the best ${count} matching products, providing one clear reason for each recommendation based on their answers.\n`;
      instruction += `4. For questions about specifications or compatibility, consult ${searchKnowledge}. Never invent specifications.\n`;
      instruction += `5. If no product fits their criteria, say so honestly and offer the closest option or offer to connect with ${handoff}.`;

      const description =
        'Use when the customer needs product recommendations, advice on choosing an item, or wants to find products matching specific needs.';

      return {
        title: 'Product finder',
        description,
        instruction,
      };
    },
  },
  {
    id: 'b2b_inquiry',
    emoji: '🏢',
    color: 'slate',
    title: 'B2B / wholesale inquiry',
    tagline: 'Qualify business inquiries and collect wholesale requirements',
    requiredTools: [],
    demo: [
      {
        role: 'customer',
        text: 'Hi, we are interested in ordering 60 units for Acme Ltd. Do you have wholesale pricing?',
      },
      { role: 'typing' },
      {
        role: 'assistant',
        text: 'Hello! Yes, we offer volume pricing for business orders. Could you share your company name, VAT or tax ID, and delivery country?',
      },
      {
        role: 'customer',
        text: 'Acme Ltd, VAT ID GB987654321, United Kingdom.',
      },
      { role: 'typing' },
      {
        role: 'assistant',
        text: 'Thank you! I have passed your inquiry to our corporate team with your details.',
        action: {
          type: 'note',
          text: 'Wholesale request: Acme Ltd (GB987654321), 60 units',
        },
        handoff:
          'Passing to our B2B team who will email you wholesale pricing within 1 business day',
      },
    ],
    questions: [
      {
        key: 'qualification_criteria',
        type: 'text',
        label: 'Who counts as a business customer?',
        helperText: 'Minimum order size or customer type for business rates.',
        default: 'companies, resellers or orders above 20 units',
        required: true,
      },
      {
        key: 'details_to_collect',
        type: 'chips',
        label: 'What details to collect',
        default: [
          'company_name',
          'vat_or_tax_id',
          'country',
          'products_and_volume',
        ],
        options: [
          { value: 'company_name', label: 'Company name' },
          { value: 'vat_or_tax_id', label: 'VAT or tax ID' },
          { value: 'country', label: 'Country' },
          {
            value: 'products_and_volume',
            label: 'Products and expected volume',
          },
          { value: 'website', label: 'Company website' },
          { value: 'contact_person', label: 'Contact person' },
        ],
      },
      {
        key: 'label',
        type: 'text',
        label: 'Conversation tag / label',
        default: 'b2b',
        required: true,
      },
      {
        key: 'reply_time',
        type: 'text',
        label: 'Promised response time',
        default: 'within 1 business day',
        required: true,
      },
    ],
    build(answers = {}, tools = []) {
      const qualification =
        answers.qualification_criteria ||
        'companies, resellers or orders above 20 units';
      const details = answers.details_to_collect || [
        'company_name',
        'vat_or_tax_id',
        'country',
        'products_and_volume',
      ];
      const label = answers.label || 'b2b';
      const replyTime = answers.reply_time || 'within 1 business day';

      const privateNote = resolveToolLink(
        'add_private_note',
        'Add a private note',
        tools
      );
      const addLabel = resolveToolLink(
        'add_label_to_conversation',
        'Add a label',
        tools
      );
      const handoff = resolveToolLink('handoff', 'Hand off to a person', tools);

      let instruction = `Handle business and wholesale inquiries qualifying under "${qualification}":\n\n`;
      instruction += `1. Collect the necessary business details one at a time, asking only for missing information:\n`;
      if (details.includes('company_name'))
        instruction += `   - Company or business name\n`;
      if (details.includes('vat_or_tax_id'))
        instruction += `   - VAT or tax registration number\n`;
      if (details.includes('country'))
        instruction += `   - Country and delivery location\n`;
      if (details.includes('products_and_volume'))
        instruction += `   - Products of interest and expected order volume\n`;
      if (details.includes('website')) instruction += `   - Company website\n`;
      if (details.includes('contact_person'))
        instruction += `   - Primary contact person\n`;
      instruction += `2. Never quote wholesale prices, contract terms, or special discounts directly in chat.\n`;
      instruction += `3. Add an internal summary note of the company and volume request using ${privateNote}.\n`;
      instruction += `4. Tag the conversation with "${label}" using ${addLabel}.\n`;
      instruction += `5. Transfer the chat to the team using ${handoff}, letting the customer know our B2B team will review and reply ${replyTime}.`;

      const description =
        'Use when a business, company, reseller or commercial customer inquires about wholesale pricing, bulk orders or corporate partnerships.';

      return {
        title: 'B2B / wholesale inquiry',
        description,
        instruction,
      };
    },
  },
];

export const getTemplateById = id =>
  SCENARIO_TEMPLATES.find(template => template.id === id);
