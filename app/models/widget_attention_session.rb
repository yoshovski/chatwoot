# The visitor's shared attention budget across tabs and conversations of one inbox.
# == Schema Information
#
# Table name: widget_attention_sessions
#
#  id               :bigint           not null, primary key
#  checked_in       :boolean          default(FALSE), not null
#  last_activity_at :datetime         not null
#  last_cue_at      :datetime
#  last_sound_at    :datetime
#  question_count   :integer          default(0), not null
#  snoozed          :boolean          default(FALSE), not null
#  started_at       :datetime         not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  contact_inbox_id :bigint           not null
#
# Indexes
#
#  index_widget_attention_sessions_on_contact_inbox_id  (contact_inbox_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (contact_inbox_id => contact_inboxes.id) ON DELETE => cascade
#
class WidgetAttentionSession < ApplicationRecord
  VISIT_TIMEOUT = 30.minutes

  belongs_to :contact_inbox

  def self.for(contact_inbox)
    find_or_create_by!(contact_inbox: contact_inbox) do |session|
      session.assign_attributes(started_at: Time.current, last_activity_at: Time.current)
    end
  end

  def active? = last_activity_at >= VISIT_TIMEOUT.ago

  # A visit ends after 30 quiet minutes; the next visit starts with a fresh budget.
  def record_activity!
    assign_attributes(started_at: Time.current, question_count: 0, checked_in: false, snoozed: false, last_cue_at: nil) unless active?
    update!(last_activity_at: Time.current)
  end
end
