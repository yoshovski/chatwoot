require 'rails_helper'

RSpec.describe ExtraAiConversationEntry do
  let(:account) { create(:account) }

  describe '.credit!' do
    it 'credits one Stripe payment once' do
      first = described_class.credit!(account: account, amount: 50, stripe_reference: 'pi_123')
      again = described_class.credit!(account: account, amount: 50, stripe_reference: 'pi_123')

      expect(again).to eq(first)
      expect(described_class.balance(account)).to eq(50)
      expect(described_class.where(stripe_reference: 'pi_123').count).to eq(1)
    end

    it 'has a unique Stripe reference in the database too' do
      described_class.credit!(account: account, amount: 50, stripe_reference: 'pi_123')
      duplicate = described_class.new(account: account, reason: 'purchase', amount: 50, remaining: 50, expires_at: 1.year.from_now,
                                      stripe_reference: 'pi_123')

      expect(duplicate).not_to be_valid
      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'records who granted an adjustment and expires 12 months after purchase' do
      user = create(:user)
      lot = described_class.credit!(account: account, amount: 5, reason: 'adjustment', user: user)

      expect(lot).to have_attributes(reason: 'adjustment', amount: 5, remaining: 5, user: user)
      expect(lot.expires_at).to be_within(1.minute).of(12.months.from_now)
    end

    it 'refuses a reason that does not add to the balance' do
      expect { described_class.credit!(account: account, amount: 5, reason: 'usage') }.to raise_error(ArgumentError)
    end
  end

  describe 'expiry' do
    it 'leaves expired lots out of the balance and writes an expiry row' do
      old_lot = travel_to(13.months.ago) { described_class.credit!(account: account, amount: 10, stripe_reference: 'pi_old') }
      described_class.credit!(account: account, amount: 3, stripe_reference: 'pi_new')

      expect(described_class.balance(account)).to eq(3)

      ExpireExtraAiConversationsJob.perform_now
      ExpireExtraAiConversationsJob.perform_now

      expect(old_lot.reload.remaining).to eq(0)
      expect(described_class.where(reason: 'expiry', lot: old_lot).pluck(:amount)).to eq([-10])
    end
  end

  describe '.use!' do
    it 'takes from the lot that expires first' do
      older = travel_to(2.months.ago) { described_class.credit!(account: account, amount: 1, stripe_reference: 'pi_older') }
      newer = described_class.credit!(account: account, amount: 1, stripe_reference: 'pi_newer')
      window = account.conversation_usage_windows.create!(started_at: Time.current, ends_at: 1.day.from_now, quota_period_start: Time.current)

      described_class.use!(window)

      expect([older.reload.remaining, newer.reload.remaining]).to eq([0, 1])
    end

    it 'returns false when nothing is left' do
      window = account.conversation_usage_windows.create!(started_at: Time.current, ends_at: 1.day.from_now, quota_period_start: Time.current)

      expect(described_class.use!(window)).to be(false)
    end
  end
end
