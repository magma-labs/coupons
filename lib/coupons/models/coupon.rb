module Coupons
  module Models
    class Coupon < ActiveRecord::Base
      # Allow using `type` as a column.
      self.inheritance_column = nil

      # Set table name.
      self.table_name = :coupons

      # Set default values.
      after_initialize do
        self.code ||= Coupons.configuration.generator.call
        self.valid_from ||= Date.current

        attachments_will_change!
        write_attribute :attachments, {} if attachments.empty?
      end

      has_many :redemptions, class_name: 'Coupons::Models::CouponRedemption'

      validates_presence_of :code, :valid_from
      validates_inclusion_of :type, in: %w[percentage amount]

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

      validate :validate_dates, :validate_code_uniqueness

      def apply(options)
        input_amount = BigDecimal("#{options[:amount]}")
        discount = BigDecimal(percentage_based? ? percentage_discount(options[:amount]) : amount)
        total = [0, input_amount - discount].max

        options = options.merge(total: total, discount: discount)

        options = Coupons.configuration.resolvers.reduce(options) do |options, resolver|
          resolver.resolve(self, options)
        end

        options
      end

      def redemptions_count
        coupon_redemptions_count
      end

      def expired?
        valid_until && valid_until <= Date.current
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

        return user_redeemed < redemption_limit_user
      end

      def started?
        valid_from <= Date.current
      end

      def redeemable?(user_id = nil)
        !expired? &&
          available_global_redemptions? &&
          available_user_redemptions?(user_id) &&
          started?
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

      def percentage_discount(input_amount)
        BigDecimal("#{input_amount}") * (BigDecimal("#{amount}") / 100)
      end

      def validate_dates
        if valid_until_before_type_cast.present?
          errors.add(:valid_until, :invalid) unless valid_until.kind_of?(Date)
          errors.add(:valid_until, :coupon_already_expired) if valid_until? && valid_until < Date.current
        end

        if valid_from.present? && valid_until.present?
          errors.add(:valid_until, :coupon_valid_until) if valid_until < valid_from
        end
      end

      def validate_code_uniqueness
        count = Coupon.where(code: code)
                  .reject { |record| record.id == id }
                  .reject(&:expired?)
                  .select { |record|
                    record.redemption_limit_global.zero? ||
                    record.coupon_redemptions_count < record.redemption_limit_global
                  }
                  .count

        errors.add(:code, :coupon_code_not_unique) if count > 0
      end
    end
  end
end
