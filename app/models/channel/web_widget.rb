# == Schema Information
#
# Table name: channel_web_widgets
#
#  id                    :integer          not null, primary key
#  allowed_domains       :text             default("")
#  continuity_via_email  :boolean          default(TRUE), not null
#  conversation_starters :jsonb            not null
#  demo_mode_enabled     :boolean          default(FALSE), not null
#  demo_slug             :string
#  feature_flags         :integer          default(7), not null
#  hmac_mandatory        :boolean          default(FALSE)
#  hmac_token            :string
#  pre_chat_form_enabled :boolean          default(FALSE)
#  pre_chat_form_options :jsonb
#  reply_time            :integer          default("in_a_few_minutes")
#  reply_time_message    :string
#  website_token         :string
#  website_url           :string
#  welcome_tagline       :string
#  welcome_title         :string
#  widget_color          :string           default("#1f93ff")
#  widget_height         :integer          default(640), not null
#  widget_icon_color     :string
#  widget_style          :string           default("standard"), not null
#  widget_text_color     :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :integer
#
# Indexes
#
#  index_channel_web_widgets_on_demo_slug      (demo_slug) UNIQUE
#  index_channel_web_widgets_on_hmac_token     (hmac_token) UNIQUE
#  index_channel_web_widgets_on_website_token  (website_token) UNIQUE
#

class Channel::WebWidget < ApplicationRecord
  include Channelable
  include FlagShihTzu

  ORDERED_TEXT_OPTION_ENABLED_VALUES = [true, false, nil].freeze

  self.table_name = 'channel_web_widgets'
  EDITABLE_ATTRS = [:website_url, :widget_color, :widget_text_color, :widget_icon_color, :widget_height, :widget_style,
                    :welcome_title, :welcome_tagline, :reply_time, :reply_time_message, :pre_chat_form_enabled,
                    :continuity_via_email, :hmac_mandatory, :allowed_domains, :demo_mode_enabled, :demo_slug,
                    { conversation_starters: [:id, :title, :enabled] },
                    { pre_chat_form_options: [:pre_chat_message, :require_email,
                                              { pre_chat_fields:
                                                [:field_type, :label, :placeholder, :name, :enabled, :type, :enabled, :required,
                                                 :locale, { values: [] }, :regex_pattern, :regex_cue] }] },
                    { selected_feature_flags: [] }].freeze

  before_validation :validate_pre_chat_options
  before_validation :normalize_conversation_starters
  before_validation :normalize_widget_colors
  before_validation :normalize_legacy_widget_style
  before_validation :normalize_demo_slug
  before_validation :ensure_demo_slug
  validates :website_url, presence: true
  validates :widget_color, presence: true
  validates :widget_text_color, :widget_icon_color,
            format: { with: /\A#(?:[0-9a-f]{3}|[0-9a-f]{6})\z/i }, allow_blank: true
  validates :widget_height,
            numericality: { only_integer: true, greater_than_or_equal_to: 320, less_than_or_equal_to: 900 }
  validates :widget_style, inclusion: { in: %w[standard] }
  validates :reply_time_message, length: { maximum: 120 }, allow_blank: true
  # The slug is the shareable part of the demo URL, so it is kept to a shape that survives being
  # pasted into a chat or an email, and unique across the instance since the route is not scoped
  # to an account.
  validates :demo_slug,
            format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ },
            length: { minimum: 2, maximum: 50 },
            uniqueness: true,
            allow_nil: true
  validate :validate_conversation_starters
  has_many :portals, foreign_key: 'channel_web_widget_id', dependent: :nullify, inverse_of: :channel_web_widget

  has_secure_token :website_token
  has_secure_token :hmac_token

  has_flags 1 => :attachments,
            2 => :emoji_picker,
            3 => :end_conversation,
            4 => :use_inbox_avatar_for_bot,
            5 => :allow_mobile_webview,
            :column => 'feature_flags',
            :check_for_column => false

  enum reply_time: { in_a_few_minutes: 0, in_a_few_hours: 1, in_a_day: 2, immediately: 3 }

  def name
    'Website'
  end

  def web_widget_script
    "
    <script>
      (function(d,t) {
        var BASE_URL=\"#{ENV.fetch('FRONTEND_URL', '')}\";
        var g=d.createElement(t),s=d.getElementsByTagName(t)[0];
        g.src=BASE_URL+\"/packs/js/sdk.js\";
        g.async = true;
        s.parentNode.insertBefore(g,s);
        g.onload=function(){
          window.chatwootSDK.run({
            websiteToken: '#{website_token}',
            baseUrl: BASE_URL
          })
        }
      })(document,\"script\");
    </script>
    "
  end

  def validate_pre_chat_options
    return if pre_chat_form_options.with_indifferent_access['pre_chat_fields'].present?

    self.pre_chat_form_options = {
      pre_chat_message: 'Share your queries or comments here.',
      pre_chat_fields: [
        {
          'field_type': 'standard', 'label': 'Email Id', 'name': 'emailAddress', 'type': 'email', 'required': true, 'enabled': false
        },
        {
          'field_type': 'standard', 'label': 'Full name', 'name': 'fullName', 'type': 'text', 'required': false, 'enabled': false
        },
        {
          'field_type': 'standard', 'label': 'Phone number', 'name': 'phoneNumber', 'type': 'text', 'required': false, 'enabled': false
        }
      ]
    }
  end

  def normalize_legacy_widget_style
    self.widget_style = 'standard' if widget_style == 'flat'
  end

  # Blank is stored as nil so the unique index does not treat two empty slugs as a collision.
  def normalize_demo_slug
    self.demo_slug = demo_slug.to_s.strip.downcase.presence
  end

  # Switching demo mode on should hand over a shareable link, not a naming task, so the slug is
  # derived from the inbox name. It stays editable for anyone who wants to choose their own.
  def ensure_demo_slug
    return unless demo_mode_enabled?
    return if demo_slug.present?

    self.demo_slug = generate_demo_slug
  end

  def generate_demo_slug
    base = inbox&.name.to_s.parameterize.first(40)
    base = 'demo' if base.length < 2
    return base if self.class.where(demo_slug: base).where.not(id: id).none?

    "#{base}-#{SecureRandom.alphanumeric(4).downcase}"
  end

  def normalize_conversation_starters
    return unless conversation_starters.is_a?(Array)

    self.conversation_starters = conversation_starters.map do |option|
      next option unless option.is_a?(Hash)

      normalized_option = option.stringify_keys
      normalized_option['enabled'] = true if normalized_option['enabled'] == 'true'
      normalized_option['enabled'] = false if normalized_option['enabled'] == 'false'
      normalized_option
    end
  end

  def normalize_widget_colors
    self.widget_text_color = normalize_hex_color(widget_text_color)
    self.widget_icon_color = normalize_hex_color(widget_icon_color)
  end

  def normalize_hex_color(color)
    return color unless color.is_a?(String)

    value = color.strip
    return if value.blank? || value == 'null'

    value = "##{value}" unless value.start_with?('#')
    value = value[0, 7] if value.match?(/\A#[0-9a-f]{8}\z/i)
    value = value[0, 4] if value.match?(/\A#[0-9a-f]{4}\z/i)
    value.downcase
  end

  def validate_conversation_starters
    validate_ordered_text_options(conversation_starters, :conversation_starters)
  end

  def validate_ordered_text_options(options, attribute)
    unless options.is_a?(Array)
      errors.add(attribute, 'must be a list')
      return
    end

    errors.add(attribute, 'can contain at most 10 items') if options.size > 10
    invalid_item = options.any? { |option| invalid_ordered_text_option?(option) }
    errors.add(attribute, 'contains an invalid item') if invalid_item
  end

  def invalid_ordered_text_option?(option)
    return true unless option.is_a?(Hash)

    values = option.with_indifferent_access
    values[:title].blank? || values[:title].length > 120 || ORDERED_TEXT_OPTION_ENABLED_VALUES.exclude?(values[:enabled])
  end

  def create_contact_inbox(additional_attributes = {})
    ::ContactInboxWithContactBuilder.new({
                                           inbox: inbox,
                                           contact_attributes: { additional_attributes: additional_attributes }
                                         }).perform
  end
end
