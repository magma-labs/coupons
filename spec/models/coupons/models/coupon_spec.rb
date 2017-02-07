require 'spec_helper'

describe Coupons::Models::Coupon do

  let(:valid_coupon_params) do
    {
      amount: 50,
      code: '556677',
      redemption_limit_global: 0,
      redemption_limit_user: 0,
      type: 'amount',
      valid_from_date: Date.current,
      valid_until_date: 3.days.from_now,
      valid_from_time: '00:00:00',
      valid_until_time: '24:00:00'
    }
  end

  def time_to_str(hour = 0, min = 0, sec = 0)
    "#{'%02d' % hour}:#{'%02d' % min}:#{'%02d' % sec}"
  end

  describe 'code' do
    it 'is required' do
      coupon = create_coupon valid_coupon_params
      coupon.code = nil

      expect(coupon).to be_invalid
      expect(coupon.errors[:code]).not_to be_empty
    end

    it 'generates default value' do
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

      it 'is accepted if other coupons with the same code are expired' do
        coupon1 = create_coupon valid_coupon_params
        coupon2 = Coupons::Models::Coupon.new valid_coupon_params
        coupon3 = Coupons::Models::Coupon.new valid_coupon_params

        coupon1.update redemption_limit_global: 1, coupon_redemptions_count: 0
        coupon2.assign_attributes(
          redemption_limit_global: 1,
          valid_from_date: coupon1.valid_until_date + 1.day,
          valid_until_date: coupon1.valid_until_date + 3.days
        )
        coupon3.assign_attributes(
          redemption_limit_global: 1,
          valid_from_date: coupon2.valid_until_date + 1.day,
          valid_until_date: coupon2.valid_until_date + 3.days
        )

        expect(coupon2).to be_valid
        coupon2.save!
        expect(coupon3).to be_valid
      end

      it 'is accepted if another coupon with the same code exists but is depleted' do
        coupon1 = create_coupon valid_coupon_params
        coupon2 = Coupons::Models::Coupon.new valid_coupon_params

        coupon1.update redemption_limit_global: 1, coupon_redemptions_count: 1
        coupon2.code = coupon1.code

        expect(coupon2).to be_valid
      end

      it 'fails if the expiration date is the same as today' do
        coupon = create_coupon valid_coupon_params
        coupon.update valid_from_date: Time.now - 1.day, valid_until_date: Time.now

        expect(coupon.expired?).to be true
      end

      it 'fails if the same code but with different letter case is being used' do
        coupon1 = Coupons::Models::Coupon.new valid_coupon_params
        coupon2 = Coupons::Models::Coupon.new valid_coupon_params
        coupon3 = Coupons::Models::Coupon.new valid_coupon_params

        coupon1.code = 'DEEPDISCOUNT'
        coupon2.code = coupon1.code.downcase
        coupon3.code = coupon1.code.each_char.map.with_index { |letter, i|
          (i % 2 == 1) ? letter.downcase : letter
        }.join('')

        coupon1.save!

        expect(coupon2).to be_invalid
        expect(coupon3).to be_invalid
      end

      it 'fails if another coupon has same code and its global limit is unlimited' do
        coupon1 = create_coupon valid_coupon_params
        coupon2 = create_coupon valid_coupon_params
        trans_msg = t('activerecord.errors.messages.coupon_code_not_unique')

        coupon1.update valid_until_date: nil
        coupon2.update(
          code: coupon1.code,
          valid_from_date: Time.now + 7.days,
          valid_until_date: Time.now + 14.days
        )

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

  describe 'valid_from_date and valid_until_date' do
    it 'requires valid expiration date' do
      coupon = create_coupon(valid_until_date: 'invalid')
      expect(coupon.errors[:valid_until_date]).not_to be_empty
    end

    it 'accepts valid expiration date' do
      coupon = create_coupon(valid_until_date: Date.current)
      expect(coupon.errors[:valid_until_date]).to be_empty

      coupon = create_coupon(valid_until_date: DateTime.current)
      expect(coupon.errors[:valid_until_date]).to be_empty

      coupon = create_coupon(valid_until_date: Time.current)
      expect(coupon.errors[:valid_until_date]).to be_empty

      Time.zone = 'UTC'
      coupon = create_coupon(valid_until_date: Time.zone.now)
      expect(coupon.errors[:valid_until_date]).to be_empty
    end

    it 'rejects expiration date' do
      coupon = create_coupon(valid_until_date: 1.day.ago)
      expect(coupon.errors[:valid_until_date]).not_to be_empty
    end

    it 'sets valid from to current date' do
      coupon = create_coupon
      expect(coupon.valid_from_date).to eq(Date.current)
    end

    it 'requires valid until to be greater than or equal to valid from' do
      coupon = create_coupon(valid_from_date: 1.day.from_now, valid_until_date: 1.day.ago)
      expect(coupon.errors[:valid_until_date]).not_to be_empty
    end

    it 'accepts valid until equal to valid from' do
      coupon = create_coupon(valid_from_date: Date.current, valid_until_date: Date.current)
      expect(coupon.errors[:valid_until_date]).to be_empty
    end

    it 'accepts valid until greater than valid from' do
      coupon = create_coupon(valid_from_date: 1.day.ago, valid_until_date: Date.current)
      expect(coupon.errors[:valid_until_date]).to be_empty
    end

    it 'accepts blank valid until' do
      coupon = create_coupon(valid_from_date: 1.day.ago)
      expect(coupon.errors[:valid_until_date]).to be_empty
    end
  end

  describe 'valid_from_time and valid_until_time' do
    let(:time_zero) { Time.utc 2000, 1, 1 }

    it "default to range '00:00:00' to '24:00:00" do
      start_time = time_zero
      end_time = time_zero + 24.hours
      coupon_params = valid_coupon_params
      coupon_params.delete :valid_from_time
      coupon_params.delete :valid_until_time
      coupon = Coupons::Models::Coupon.new valid_coupon_params

      coupon.save!

      expect(coupon.reload).to be_valid
      expect(coupon.valid_from_time).to eq start_time
      expect(coupon.valid_until_time).to eq end_time
    end

    it 'accept valid start to end minutes' do
      coupon = Coupons::Models::Coupon.new valid_coupon_params

      coupon.assign_attributes valid_from_time: time_zero, valid_until_time: time_zero + 24.hours
      expect(coupon).to be_valid

      coupon.assign_attributes valid_from_time: '1:00:00', valid_until_time: '3:00:00'
      expect(coupon).to be_valid
    end

    it 'rejects invalid start to end minutes' do
      start_min = time_zero
      end_min = start_min + 2.hours
      coupon = Coupons::Models::Coupon.new valid_coupon_params

      coupon.assign_attributes valid_from_time: end_min, valid_until_time: start_min
      expect(coupon).to be_invalid
      expect(coupon.errors[:valid_until_time])
        .to include t('activerecord.errors.messages.coupon_valid_until_time')
    end

    it 'rejects non-Time objects' do
      test_time = '10:00:00'
      coupon = Coupons::Models::Coupon.new valid_coupon_params

      coupon.assign_attributes valid_from_time: Object.new, valid_until_time: test_time
      expect(coupon).to be_invalid
      expect(coupon.errors[:valid_until_time])
        .to include t('activerecord.errors.messages.coupon_valid_until_time')

      coupon.assign_attributes valid_from_time: test_time, valid_until_time: Object.new
      expect(coupon).to be_invalid
      expect(coupon.errors[:valid_until_time])
        .to include t('activerecord.errors.messages.coupon_valid_until_time')
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

  describe '#expired?' do
    it "returns false if valid date range" do
      coupon = Coupons::Models::Coupon.new valid_coupon_params

      coupon.assign_attributes valid_from_date: Time.now, valid_until_date: 2.days.from_now
      coupon.save!

      expect(coupon).not_to be_expired
    end

    it "returns true if date range is in the past" do
      mock_date = 3.days.from_now
      future_date = Date.new mock_date.year, mock_date.month, mock_date.day
      coupon = Coupons::Models::Coupon.new valid_coupon_params

      coupon.assign_attributes valid_from_date: Time.now, valid_until_date: mock_date - 1.day
      coupon.save!

      allow(Date).to receive(:current) { future_date }
      expect(coupon).to be_expired
    end
  end

  describe '#valid_times?' do
    let(:hour) { 10 }
    let(:min) { 15 }
    let(:today) { Date.current }

    it 'returns true if valid timeframe' do
      mock_time = Time.utc today.year, today.month, today.day, hour, min
      coupon = Coupons::Models::Coupon.new valid_coupon_params

      allow(Time).to receive(:now) { mock_time.utc }

      coupon.assign_attributes valid_from_time: time_to_str, valid_until_time: time_to_str(24)
      coupon.save!
      expect(coupon).to be_valid_times

      min_from = time_to_str(hour)
      min_until = time_to_str(hour, min + 15)
      coupon.update valid_from_time: min_from, valid_until_time: min_until
      expect(coupon).to be_valid_times

      min_from = time_to_str(hour, min)
      min_until = time_to_str(hour, min + 1)
      coupon.update valid_from_time: min_from, valid_until_time: min_until
      expect(coupon).to be_valid_times
    end

    it 'returns false if invalid timeframe' do
      mock_time = Time.new today.year, today.month, today.day, hour, min
      coupon = create_coupon valid_coupon_params

      allow(Time).to receive(:now) { mock_time.localtime }

      coupon.update valid_from_time: time_to_str(10, min - 15), valid_until_time: time_to_str(10, min)
      expect(coupon).not_to be_valid_times

      coupon.update valid_from_time: time_to_str(10, min + 1), valid_until_time: time_to_str(10, min + 15)
      expect(coupon).not_to be_valid_times
    end
  end

  describe '#redeemable?' do
    it 'if not expired' do
      coupon = create_coupon valid_coupon_params
      coupon.valid_until_date = 3.days.from_now
      expect(coupon).to be_redeemable
    end

    it 'if within valid time range' do
      hour = 10
      min = 15
      today = Date.current
      coupon = create_coupon valid_coupon_params

      mock_time = Time.utc today.year, today.month, today.day, hour, min
      allow(Time).to receive(:now) { mock_time.utc }

      coupon.update(
        valid_from_date: today, valid_until_date: today + 1.day,
        valid_from_time: time_to_str(0), valid_until_time: time_to_str(24, 0, 0)
      )
      expect(coupon).to be_redeemable

      coupon.update(
        valid_from_date: today, valid_until_date: today + 1.day,
        valid_from_time: time_to_str(hour, min), valid_until_time: time_to_str(hour, min + 1)
      )
      expect(coupon).to be_redeemable

      coupon.update(
        valid_from_date: today, valid_until_date: today + 1.day,
        valid_from_time: time_to_str(hour), valid_until_time: time_to_str(hour, min + 30)
      )
      expect(coupon).to be_redeemable
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

    it "fails if expired" do
      coupon = create_coupon(amount: 100, type: 'amount')
      Coupons::Models::Coupon.update_all valid_until_date: 3.days.ago

      expect(coupon.reload).not_to be_redeemable
    end

    it 'fails if current date > starting date' do
      coupon = create_coupon(amount: 100, type: 'amount', valid_from_date: 3.days.from_now)
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
