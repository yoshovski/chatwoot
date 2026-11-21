class AddOutOfOfficeMessageTranslationsToInboxes < ActiveRecord::Migration[7.2]
  def change
    add_column :inboxes, :out_of_office_message_translations, :jsonb, default: {}, null: false
  end
end
