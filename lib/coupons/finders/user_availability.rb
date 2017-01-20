module Coupons
  module Finders
    # Possible return status: found, not_found, limit_exceeded
    UserAvailability = proc do |code, options = {}|
      coupons = Models::Coupon
                  .where("LOWER(code) = ?", code.try(:downcase))
                  .select { |coupon| coupon.started? && !coupon.expired? }

      selected_coupon = coupons.first
      options[:status] = 'not_found'
      terminate = false

      terminate = true if selected_coupon.nil?

      if !terminate && selected_coupon.redemption_limit_user.zero?
        if selected_coupon.redeemable?
          options[:status] = 'found'
        else
          selected_coupon = nil
        end

        terminate = true
      end

      if !terminate
        user_id = options[:user_id]

        if user_id.blank?
          selected_coupon = nil
          terminate = true
        end
      end

      if !terminate && !selected_coupon.redeemable?(user_id)
        options[:status] = 'limit_exceeded'
        selected_coupon = nil
        terminate = true
      end

      options[:status] = 'found' if !terminate

      selected_coupon
    end
  end
end
