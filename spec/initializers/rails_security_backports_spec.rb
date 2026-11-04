require 'rails_helper'

# Covers config/initializers/monkey_patches/rails_security_backports.rb.
# Delete together with that file once Rails is >= 8.0.5.2.
RSpec.describe 'Rails security backports' do # rubocop:disable RSpec/DescribeClass
  describe 'ActiveSupport::Inflector#safe_constantize (GHSA-8474-xrp6-wh69)' do
    # Runs the patched safe_constantize with a constantize that raises LoadError(message).
    let(:inflector) do
      error_message = message
      Object.new.extend(ActiveSupport::Inflector).tap do |object|
        object.define_singleton_method(:constantize) { |_name| raise LoadError, error_message }
      end
    end

    context 'when the LoadError names a different constant' do
      let(:message) { 'Unable to autoload constant ExampleXChannel' }

      it 'matches the name as a literal string, not a pattern' do
        expect { inflector.safe_constantize('Example.Channel') }.to raise_error(LoadError)
        expect { inflector.safe_constantize('Example.Channel::Nested') }.to raise_error(LoadError)
      end
    end

    context 'when the LoadError names the requested constant' do
      let(:message) { 'Unable to autoload constant Example.Channel' }

      it 'returns nil' do
        expect(inflector.safe_constantize('Example.Channel::Nested')).to be_nil
      end
    end

    it 'keeps normal lookups working' do
      expect('RoomChannel'.safe_constantize).to eq(RoomChannel)
      expect('NoSuchChannelAnywhere'.safe_constantize).to be_nil
    end
  end

  describe 'ActionController::Parameters#each_key (GHSA-wm3x-v3qw-4jh3)' do
    let(:params) { ActionController::Parameters.new(name: 'Bob', admin: true) }

    it 'returns the Parameters instance when given a block' do
      expect(params.each_key { |_key| nil }).to be(params)
    end

    it 'yields each key and returns an enumerator without a block' do
      keys = []
      params.each_key { |key| keys << key }

      expect(keys).to eq(%w[name admin])
      expect(params.each_key.to_a).to eq(%w[name admin])
    end

    it 'is not accepted by mass assignment' do
      expect { User.new(params.each_key { |_key| nil }) }.to raise_error(ActionController::UnfilteredParameters)
    end
  end
end
