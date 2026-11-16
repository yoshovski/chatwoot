# A claim is consumed even if the presenting tab closes. Ambiguous delivery must never be replayed.
# == Schema Information
#
# Table name: widget_attention_events
#
#  id               :bigint           not null, primary key
#  event_key        :string           not null
#  kind             :string           not null
#  status           :string           default("claimed"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  contact_inbox_id :bigint           not null
#  conversation_id  :bigint           not null
#  message_id       :bigint           not null
#
# Indexes
#
#  index_widget_attention_events_on_claim                     (contact_inbox_id,event_key) UNIQUE
#  index_widget_attention_events_on_contact_inbox_id          (contact_inbox_id)
#  index_widget_attention_events_on_conversation_id           (conversation_id)
#  index_widget_attention_events_on_conversation_id_and_kind  (conversation_id,kind)
#  index_widget_attention_events_on_message_id                (message_id)
#
# Foreign Keys
#
#  fk_rails_...  (contact_inbox_id => contact_inboxes.id) ON DELETE => cascade
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => cascade
#  fk_rails_...  (message_id => messages.id) ON DELETE => cascade
#
class WidgetAttentionEvent < ApplicationRecord
  belongs_to :contact_inbox
  belongs_to :conversation
  belongs_to :message

  validates :kind, inclusion: { in: %w[question check_in sound] }
  validates :status, inclusion: { in: %w[claimed presented dismissed expired] }
end
