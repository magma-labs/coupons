module Coupons
  class RecurrenceType
    def self.to_select
      [
        [I18n.t('coupons.coupon.recurrence_type.weekly'), 'Coupons::Models::CouponWeekly']
      ]
    end
  end
end
