module Coupons
  module Models
    class CouponWeekly < Coupon

      RECURRENCE_VALUES = (0..6)

      validates_presence_of :recurrence
      validate :validate_recurrence

      def apply(options)
        input_amount = BigDecimal(options[:amount].to_s)
        discount = BigDecimal(
          percentage_based? ? percentage_discount(options[:amount]) : amount
        )
        total = [0, input_amount - discount].max

        options = options.merge(total: total, discount: discount)

        options =
          Coupons.configuration.resolvers
            .reduce(options) { |options, resolver| resolver.resolve(self, options) }

        options
      end

      def valid_recurrence?
        recurrence['days'].include? Time.zone.now.wday
      end

      def redeemable?(user_id = nil)
        super && valid_recurrence?
      end

      private

      def validate_recurrence
        days = recurrence['days'].map(&:to_i)
        min_max_correct = days.min >= RECURRENCE_VALUES.min && days.max <= RECURRENCE_VALUES.max
        count_correct = days.select { |wday| days.count(wday) > 1 }.empty?

        errors.add(:recurrence, :coupon_recurrence) unless min_max_correct && count_correct
      end

      def recurrence_overlaps?(coupon)
        case coupon
        when Coupons::Models::CouponWeekly
          (recurrence['days'] & coupon.recurrence['days']).any?
        when Coupons::Models::Coupon
          false
        end
      end

      def overlaps?(coupon)
        super && recurrence_overlaps?(coupon)
      end

      def validate_code_uniqueness
        query =
          "LOWER(code) = ? AND " +
          "(redemption_limit_global = 0 OR coupon_redemptions_count < redemption_limit_global)"

        count =
          Coupon.where(query, code.try(:downcase)).where.not(id: id)
          .select { |coupon| overlaps?(coupon) }
          .count

        errors.add(:code, :coupon_code_not_unique) if count > 0
      end
    end
  end
end
