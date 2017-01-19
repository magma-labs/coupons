require 'spec_helper'

describe Coupons::Models::Coupon do

  let(:valid_coupon_params) do
    {
      code: '556677',
      amount: 50,
      type: 'amount',
      redemption_limit_global: 0,
      redemption_limit_user: 0,
      valid_from: 2.days.ago,
      valid_until: 3.days.from_now
    }
  end

  context 'fields' do
    describe 'code' do
      it 'is required' do
        coupon = create_coupon
        coupon.code = nil
        coupon.valid?

        expect(coupon.errors[:code]).not_to be_empty
      end

      it 'generates default coupon code' do
        coupon = create_coupon
        expect(coupon.code).to match(/^[A-Z0-9]{6}$/)
      end

      context 'must be unique among valid coupons' do
        it 'is accepted if code is unique' do
          coupon1 = create_coupon valid_coupon_params
          coupon2 = Coupons::Models::Coupon.new coupon1.attributes

          coupon2.code = coupon1.code.to_i + 1

          expect(coupon2).to be_valid
        end

        it 'is accepted if another coupon with the same code exists but is depleted' do
          coupon1 = create_coupon valid_coupon_params
          coupon2 = Coupons::Models::Coupon.new valid_coupon_params

          coupon1.update redemption_limit_global: 1, coupon_redemptions_count: 1
          coupon2.code = coupon1.code

          expect(coupon2).to be_valid
        end

        it 'fails if another coupon has same code and its global limit is unlimited' do
          coupon1 = create_coupon valid_coupon_params
          coupon2 = create_coupon valid_coupon_params
          trans_msg = t('activerecord.errors.messages.coupon_code_not_unique')

          coupon2.code = coupon1.code

          expect(coupon2).to be_invalid
          expect(coupon2.errors[:code]).to include(trans_msg)
        end

        it "fails if another coupon has same code and isn't depeted" do
          coupon1 = create_coupon valid_coupon_params
          coupon2 = Coupons::Models::Coupon.new valid_coupon_params
          trans_msg = t('activerecord.errors.messages.coupon_code_not_unique')

          coupon1.update(redemption_limit_global: 1, coupon_redemptions_count: 0)
          coupon2.code = coupon1.code

          expect(coupon2).to be_invalid
          expect(coupon2.errors[:code]).to include(trans_msg)
        end
      end
    end

    describe 'type' do
      it 'is required' do
        coupon = create_coupon
        expect(coupon.errors[:type]).not_to be_empty
      end

      it 'is valid' do
        coupon = create_coupon(type: 'invalid')
        expect(coupon.errors[:type]).not_to be_empty
      end
    end

    describe 'valid_from and valid_until' do
      it 'requires valid expiration date' do
        coupon = create_coupon(valid_until: 'invalid')
        expect(coupon.errors[:valid_until]).not_to be_empty
      end

      it 'accepts valid expiration date' do
        coupon = create_coupon(valid_until: Date.current)
        expect(coupon.errors[:valid_until]).to be_empty

        coupon = create_coupon(valid_until: DateTime.current)
        expect(coupon.errors[:valid_until]).to be_empty

        coupon = create_coupon(valid_until: Time.current)
        expect(coupon.errors[:valid_until]).to be_empty

        Time.zone = 'UTC'
        coupon = create_coupon(valid_until: Time.zone.now)
        expect(coupon.errors[:valid_until]).to be_empty
      end

      it 'rejects expiration date' do
        coupon = create_coupon(valid_until: 1.day.ago)
        expect(coupon.errors[:valid_until]).not_to be_empty
      end

      it 'sets valid from to current date' do
        coupon = create_coupon
        expect(coupon.valid_from).to eq(Date.current)
      end

      it 'requires valid until to be greater than or equal to valid from' do
        coupon = create_coupon(valid_from: 1.day.from_now, valid_until: 1.day.ago)
        expect(coupon.errors[:valid_until]).not_to be_empty
      end

      it 'accepts valid until equal to valid from' do
        coupon = create_coupon(valid_from: Date.current, valid_until: Date.current)
        expect(coupon.errors[:valid_until]).to be_empty
      end

      it 'accepts valid until greater than valid from' do
        coupon = create_coupon(valid_from: 1.day.ago, valid_until: Date.current)
        expect(coupon.errors[:valid_until]).to be_empty
      end

      it 'accepts blank valid until' do
        coupon = create_coupon(valid_from: 1.day.ago)
        expect(coupon.errors[:valid_until]).to be_empty
      end
    end

    describe 'amount' do
      it 'requires valid range for percentage based coupons' do
        coupon = create_coupon(amount: -1, type: 'percentage')
        expect(coupon.errors[:amount]).not_to be_empty

        coupon = create_coupon(amount: 101, type: 'percentage')
        expect(coupon.errors[:amount]).not_to be_empty

        coupon = create_coupon(amount: 10.5, type: 'percentage')
        expect(coupon.errors[:amount]).not_to be_empty
      end

      it 'accepts amount for percentage based coupons' do
        coupon = create_coupon(amount: 0, type: 'percentage')
        expect(coupon.errors[:amount]).to be_empty

        coupon = create_coupon(amount: 100, type: 'percentage')
        expect(coupon.errors[:amount]).to be_empty

        coupon = create_coupon(amount: 50, type: 'percentage')
        expect(coupon.errors[:amount]).to be_empty
      end

      it 'requires amount to be a positive number for amount based coupons' do
        coupon = create_coupon(amount: -1, type: 'amount')
        expect(coupon.errors[:amount]).not_to be_empty
      end

      it 'accepts non-zero amount for amount based coupons' do
        coupon = create_coupon(amount: 1000, type: 'amount')
        expect(coupon.errors[:amount]).to be_empty
      end
    end

    describe 'redemption_limit_global' do
      it 'requires non-zero global redemption limit' do
        coupon = create_coupon(redemption_limit_global: -1)
        expect(coupon.errors[:redemption_limit_global]).not_to be_empty

        coupon = create_coupon(redemption_limit_global: 0)
        expect(coupon.errors[:redemption_limit_global]).to be_empty

        coupon = create_coupon(redemption_limit_global: 100)
        expect(coupon.errors[:redemption_limit_global]).to be_empty
      end
    end

    describe 'redemption_limit_user' do
      it 'requires non-zero user redemption limit' do
        coupon = create_coupon(redemption_limit_user: -1)
        expect(coupon.errors[:redemption_limit_user]).not_to be_empty

        coupon = create_coupon(redemption_limit_user: 0)
        expect(coupon.errors[:redemption_limit_user]).to be_empty

        coupon = create_coupon(redemption_limit_user: 100)
        expect(coupon.errors[:redemption_limit_user]).to be_empty
      end
    end

    describe 'attachments' do
      it 'sets default attachments object for new records' do
        coupon = Coupons::Models::Coupon.new
        expect(coupon.attachments).to eq({})
      end

      it 'saves default attachments object' do
        coupon = create_coupon(amount: 10, type: 'amount')
        coupon.reload

        expect(coupon.attachments).to eq({})
      end
    end
  end

  describe '#redeemable?' do

    it 'if not expired' do
      coupon = create_coupon valid_coupon_params
      coupon.valid_until = 3.days.from_now
      expect(coupon.reload).to be_redeemable
    end

    it 'if no global limit is set' do
      coupon = create_coupon valid_coupon_params
      coupon.redemption_limit_global = 0
      expect(coupon.reload).to be_redeemable
    end

    it 'if no user limit is set' do
      coupon = create_coupon valid_coupon_params
      coupon.redemption_limit_user = 0
      expect(coupon.reload).to be_redeemable
    end

    it 'if no global limit is set and no user limit is set' do
      coupon = create_coupon valid_coupon_params
      coupon.attributes = { redemption_limit_global: nil, redemption_limit_user: nil }
      expect(coupon.reload).to be_redeemable
    end

    it 'if there are globally available redemptions' do
      coupon = create_coupon valid_coupon_params
      coupon.redemption_limit_global = 5
      expect(coupon.reload).to be_redeemable
    end

    it 'if there are available redemptions for user and current user id is defined' do
      coupon = create_coupon valid_coupon_params
      user_limit = 3
      user_id = 43
      options = { amount: 200, user_id: user_id }

      coupon.update(redemption_limit_user: user_limit)
      (user_limit - 1).times { Coupons.redeem(coupon.code, options) }

      expect(coupon.redeemable?(user_id)).to be true
    end

    it 'fails if there are available redemptions for user but current user id is undefined' do
      coupon = create_coupon valid_coupon_params
      user_limit = 3
      user_id = 43
      options = { amount: 200, user_id: user_id }

      coupon.update(redemption_limit_user: user_limit)
      (user_limit - 1).times { Coupons.redeem(coupon.code, options) }

      expect(coupon.redeemable?).to be false
    end

    it 'fails if user availability is exceeded' do
      coupon = create_coupon valid_coupon_params
      user_limit = 3
      user_id = 43
      options = { amount: 200, user_id: user_id }

      coupon.update(redemption_limit_user: user_limit)
      user_limit.times { Coupons.redeem(coupon.code, options) }

      expect(coupon.redeemable?(user_id)).to be false
    end

    it "fails if it's expired" do
      coupon = create_coupon(amount: 100, type: 'amount')
      Coupons::Models::Coupon.update_all valid_until: 3.days.ago
      coupon.reload

      expect(coupon.reload).not_to be_redeemable
    end

    it 'fails if current date > starting date' do
      coupon = create_coupon(amount: 100, type: 'amount', valid_from: 3.days.from_now)
      expect(coupon.reload).not_to be_redeemable
    end

    it 'fails if no available redemptions' do
      coupon = create_coupon(amount: 100, type: 'amount')
      coupon.redemptions.create!

      expect(coupon.reload).not_to be_redeemable
    end
  end

  describe 'serialization' do
    let!(:category) { Category.create!(name: 'Books') }
    let!(:product) { category.products.create!(name: 'All about Rails', price: 29) }

    it 'saves attachments' do
      coupon = create_coupon(
        amount: 10,
        type: 'amount',
        attachments: { category: category }
      )

      expect(coupon.reload.attachments[:category]).to eq(category)
    end

    it 'returns missing attachments as nil' do
      coupon = create_coupon(
        amount: 10,
        type: 'amount',
        attachments: { category: category }
      )

      category.destroy
      coupon.reload

      expect(coupon.attachments[:category]).to be_nil
    end
  end
end
