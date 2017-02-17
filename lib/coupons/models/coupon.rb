module Coupons
  module Models
    class Coupon < ActiveRecord::Base

      # Set table name.
      self.table_name = :coupons

      # Single Table Inheritance
      self.inheritance_column = :recurrence_type

      # Set default values.
      after_initialize do
        self.code ||= Coupons.configuration.generator.call
        self.recurrence_type ||= 'Coupons::Models::Coupon'
        self.valid_from_date ||= Date.current

        attachments_will_change!
        write_attribute :attachments, {} if attachments.empty?
      end


      has_many :redemptions, class_name: 'Coupons::Models::CouponRedemption'

      validates_presence_of :code, :valid_from_date
      validates_inclusion_of :type, in: %w(percentage amount)

      serialize :attachments, GlobalidSerializer

      validates_numericality_of :amount,
                                greater_than_or_equal_to: 0,
                                less_than_or_equal_to: 100,
                                only_integer: true,
                                if: :percentage_based?

      validates_numericality_of :amount,
                                greater_than_or_equal_to: 0,
                                only_integer: true,
                                if: :amount_based?

      validates_numericality_of :redemption_limit_global,
                                greater_than_or_equal_to: 0

      validates_numericality_of :redemption_limit_user,
                                greater_than_or_equal_to: 0

      validate :validate_amount, :validate_dates, :validate_times, :validate_code_uniqueness

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

      def redemptions_count
        coupon_redemptions_count
      end

      def expired?
        (valid_until_date || false) && valid_until_date <= Date.current
      end

      def valid_times?
        hms = "%H%M%S"
        time_str = Time.zone.now.strftime(hms)
        vft_str = valid_from_time.strftime(hms)
        vit_str = valid_until_time.day == 2 ? '24:00:00' : valid_until_time.strftime(hms)

        time_str >= vft_str && time_str < vit_str
      end

      def available_global_redemptions?
        redemption_limit_global.zero? ||
          redemptions_count < redemption_limit_global
      end

      def available_user_redemptions?(user_id)
        # return true if no user limit
        return true if redemption_limit_user.zero?
        # return false if user limit set but user_id is blank
        return false if user_id.blank?

        user_redeemed = redemptions.where(user_id: user_id).count

        user_redeemed < redemption_limit_user
      end

      def started?
        valid_from_date <= Time.zone.now
      end

      def redeemable?(user_id = nil)
        started? && !expired? && valid_times? &&
          available_global_redemptions? &&
          available_user_redemptions?(user_id)
      end

      def to_partial_path
        'coupons/coupon'
      end

      def percentage_based?
        type == 'percentage'
      end

      def amount_based?
        type == 'amount'
      end

      private

      def ends_before_this_starts?(self_valid_from, coupon_valid_until)
        if self_valid_from && coupon_valid_until
          self_valid_from >= coupon_valid_until
        else
          false
        end
      end

      def starts_after_this_ends?(self_valid_until, coupon_valid_from)
        if self_valid_until && coupon_valid_from
          self_valid_until <= coupon_valid_from
        else
          false
        end
      end

      def overlaps?(coupon)
        dates_overlap = !(
          ends_before_this_starts?(valid_from_date, coupon.valid_until_date) ||
          starts_after_this_ends?(valid_until_date, coupon.valid_from_date)
        )

        times_overlap = !(
          ends_before_this_starts?(valid_from_time, coupon.valid_until_time) ||
          starts_after_this_ends?(valid_until_time, coupon.valid_from_time)
        )

        dates_overlap ? (dates_overlap && times_overlap) : false
      end

      def percentage_discount(input_amount)
        BigDecimal("#{input_amount}") * (BigDecimal("#{amount}") / 100)
      end

      def validate_amount
         errors.add(:amount, :invalid) if amount.zero?
      end

      def validate_dates
        if valid_until_date_before_type_cast.present?
          errors.add(:valid_until_date, :invalid) unless valid_until_date.kind_of?(Date)
          errors.add(:valid_until_date, :coupon_already_expired) if valid_until_date? && valid_until_date < Date.current &&
          valid_from_date > valid_until_date
        end

        if valid_from_date.present? && valid_until_date.present?
          errors.add(:valid_until_date, :coupon_valid_until) if valid_until_date < valid_from_date
        end
      end

      def validate_times
        is_valid =
          Time === valid_from_time && Time === valid_until_time &&
          valid_from_time < valid_until_time

        errors.add(:valid_until_time, :coupon_valid_until_time) unless is_valid
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
