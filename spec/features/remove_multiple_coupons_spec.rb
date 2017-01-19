require 'spec_helper'
require 'byebug'

feature 'Remove multiple coupons', js: true do
  scenario 'remove all selected' do
    3.times { create_coupon(type: 'amount', amount: 10) }

    visit '/coupons'

    check('coupon-selector')
    sleep 0.2
    click_button t('coupons.coupon.buttons.remove_selected')

    expect(current_path).to eq('/coupons')
    expect(page).to have_text(notice('coupons.batch.removal'))
    expect(all('.coupon')).to be_empty
  end

  scenario 'remove only selected' do
    3.times { create_coupon(type: 'amount', amount: 10) }

    visit '/coupons'

    find('.coupon:nth-child(1)').check('coupon_ids[]')
    sleep 0.2
    click_button t('coupons.coupon.buttons.remove_selected')

    expect(current_path).to eq('/coupons')
    expect(page).to have_text(notice('coupons.batch.removal'))
    expect(all('.coupon').size).to eq(2)
  end
end
