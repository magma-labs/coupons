module Coupons
  module Finders
    UserAvailability = proc do |code, options = {}|
      coupons = Models::Coupon.where(code: code).select do |coupon|
        if coupon.redemption_limit_user.zero?
          coupon.redeemable?
        else
          user_id = options[:user_id]

          if user_id.blank?
            false
          else
            user_id = user_id.to_s.strip
            coupon.redeemable? user_id
          end
        end
      end

      coupons.first
    end
  end
end
