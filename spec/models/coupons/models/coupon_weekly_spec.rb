require 'spec_helper'

describe Coupons::Models::CouponWeekly do

  let(:valid_coupon_params) do
    {
      code: '556677',
      redemption_limit_global: 0,
      redemption_limit_user: 0,
      type: 'amount',
      amount: 50,
      valid_from_date: Date.current,
      valid_until_date: 3.days.from_now,
      valid_from_time: '00:00:00',
      valid_until_time: '24:00:00',
      recurrence: { days: [0, 6] }
    }
  end

  describe '#valid_recurrence?' do
    it 'is true if valid day of the week' do
      time = Time.zone.now
      coupon = Coupons::Models::CouponWeekly.new valid_coupon_params
      wday_today = time.wday
      wday_in_two_days = (time + 2.days).wday

      coupon.recurrence = { days: [wday_today, wday_in_two_days] }

      expect(coupon).to be_valid
    end

    it 'is false if days of week out of range' do
      time = Time.zone.now
      coupon = Coupons::Models::CouponWeekly.new valid_coupon_params
      wday_today = time.wday
      wday_invalid = Coupons::Models::CouponWeekly::RECURRENCE_VALUES.max + 1

      coupon.recurrence = { days: [wday_today, wday_invalid] }

      expect(coupon).to be_invalid
      expect(coupon.errors[:recurrence])
        .to include t('activerecord.errors.messages.coupon_recurrence')
    end
  end

  describe '#redeemable?' do
    it 'is true if valid day of the week' do
      mocked_date = Time.zone.now
      coupon = Coupons::Models::CouponWeekly.new valid_coupon_params
      wday_today = mocked_date.wday.to_s
      wday_in_two_days = (mocked_date + 2.days).wday
      coupon.recurrence = { days: [wday_today, wday_in_two_days] }

      allow(Time).to receive(:now) { mocked_date }

      expect(coupon).to be_redeemable
    end

    it 'is false if invalid day of the week' do
      mocked_date = Time.zone.now
      coupon = Coupons::Models::CouponWeekly.new valid_coupon_params
      wday_yesterday = (mocked_date - 1.day).wday
      wday_tomorrow = (mocked_date + 1.day).wday
      coupon.recurrence = { days: [wday_yesterday, wday_tomorrow] }

      allow(Time).to receive(:now) { mocked_date }

      expect(coupon).not_to be_redeemable
    end
  end

  describe '#overlaps?' do
    it "is false if two coupons don't share recurrence frequency" do
      coupon1 = Coupons::Models::CouponWeekly.new valid_coupon_params
      coupon1.recurrence = { days: [0, 1] }
      coupon2 = Coupons::Models::CouponWeekly.new valid_coupon_params
      coupon2.assign_attributes code: (coupon1.code.to_i + 1), recurrence: { days: [2, 3] }

      coupon1.save!

      expect(coupon2).to be_valid
    end

    it 'returns false if two copuons share any recurrence frequency' do
      coupon1 = Coupons::Models::CouponWeekly.new valid_coupon_params
      coupon1.update recurrence: { days: [0, 1] }
      coupon2 = Coupons::Models::CouponWeekly.new valid_coupon_params
      coupon2.assign_attributes code: coupon1.code, recurrence: { days: [1, 3] }
      trans_msg = t('activerecord.errors.messages.coupon_code_not_unique')

      coupon1.save!

      expect(coupon2).to be_invalid
      expect(coupon2.errors[:code]).to include trans_msg
    end
  end
end
