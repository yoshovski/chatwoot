RSpec.shared_context 'with Dify credential encryption' do
  around do |example|
    key = ActiveRecord::Encryption::Key.new('k' * 32)
    provider = ActiveRecord::Encryption::KeyProvider.new(key)
    ActiveRecord::Encryption.with_encryption_context(key_provider: provider) { example.run }
  end
end
