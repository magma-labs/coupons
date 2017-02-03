class SetupCoupons < ActiveRecord::Migration
  def change

    create_table :coupons do |t|
      t.string :code, null: false
      t.string :description, null: true
      t.date :valid_from_date, null: false
      t.date :valid_until_date, null: true
      t.time :valid_from_time, default: '00:00:00', null: false
      t.time :valid_until_time, default: '24:00:00', null: false
      t.integer :redemption_limit_global, default: 1, null: false
      t.integer :redemption_limit_user, default: 0, null: false
      t.integer :coupon_redemptions_count, default: 0, null: false
      t.integer :amount, null: false, default: 0
      t.string :type, null: false
      t.timestamps null: false

      case ActiveRecord::Base.connection.adapter_name
      when 'Mysql2'
        t.text :attachments
      else
        t.text :attachments, null: false, default: '{}'
      end
    end

    create_table :coupon_redemptions do |t|
      t.belongs_to :coupon, null: false
      t.string :user_id, null: true
      t.string :order_id, null: true
      t.timestamps null: false
    end
  end
end
