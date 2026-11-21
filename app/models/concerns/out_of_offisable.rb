# frozen_string_literal: true

module OutOfOffisable
  extend ActiveSupport::Concern

  OFFISABLE_ATTRS = %w[day_of_week closed_all_day open_hour open_minutes close_hour close_minutes open_all_day].freeze
  DEFAULT_WORKING_HOURS = [
    { day_of_week: 0, closed_all_day: true, open_all_day: false },
    { day_of_week: 1, open_hour: 9, open_minutes: 0, close_hour: 17, close_minutes: 0, open_all_day: false },
    { day_of_week: 2, open_hour: 9, open_minutes: 0, close_hour: 17, close_minutes: 0, open_all_day: false },
    { day_of_week: 3, open_hour: 9, open_minutes: 0, close_hour: 17, close_minutes: 0, open_all_day: false },
    { day_of_week: 4, open_hour: 9, open_minutes: 0, close_hour: 17, close_minutes: 0, open_all_day: false },
    { day_of_week: 5, open_hour: 9, open_minutes: 0, close_hour: 17, close_minutes: 0, open_all_day: false },
    { day_of_week: 6, closed_all_day: true, open_all_day: false }
  ].map(&:freeze).freeze

  included do
    has_many :working_hours, dependent: :destroy_async
    after_create :create_default_working_hours
    validate :validate_out_of_office_message_translations
  end

  def out_of_office?
    working_hours_enabled? && working_hours.today.closed_now?
  end

  def out_of_office_message_configured?
    out_of_office_message.present? || out_of_office_message_translations.present?
  end

  def out_of_office_message_for(locale)
    requested = locale.to_s.tr('-', '_').downcase
    variants = out_of_office_message_translations
    matching_locale = variants.keys.find { |key| key.casecmp?(requested) }
    variants[matching_locale].presence || variants[requested.split('_').first].presence || out_of_office_message
  end

  def working_now?
    !out_of_office?
  end

  def weekly_schedule
    working_hours.sort_by(&:day_of_week).map do |wh|
      {
        'day_of_week' => wh.day_of_week,
        'closed_all_day' => wh.closed_all_day,
        'open_hour' => wh.open_hour,
        'open_minutes' => wh.open_minutes,
        'close_hour' => wh.close_hour,
        'close_minutes' => wh.close_minutes,
        'open_all_day' => wh.open_all_day
      }
    end
  end

  # accepts an array of hashes similiar to the format of weekly_schedule
  #  [
  #    { "day_of_week"=>1,
  #      "closed_all_day"=>false,
  #      "open_hour"=>9,
  #      "open_minutes"=>0,
  #      "close_hour"=>17,
  #      "close_minutes"=>0,
  #      "open_all_day=>false" },...]
  def update_working_hours(params)
    ActiveRecord::Base.transaction do
      params.each do |working_hour|
        working_hours.find_by(day_of_week: working_hour['day_of_week']).update(working_hour.slice(*OFFISABLE_ATTRS))
      end
    end
  end

  private

  def validate_out_of_office_message_translations
    variants = out_of_office_message_translations
    return if variants.is_a?(Hash) && variants.all? { |locale, message| valid_out_of_office_translation?(locale, message) }

    errors.add(:out_of_office_message_translations, :invalid)
  end

  def valid_out_of_office_translation?(locale, message)
    I18n.locale_available?(locale) && message.is_a?(String) && message.present? && message.length <= Limits::OUT_OF_OFFICE_MESSAGE_MAX_LENGTH
  end

  def create_default_working_hours
    DEFAULT_WORKING_HOURS.each { |attributes| working_hours.create!(attributes) }
  end
end
