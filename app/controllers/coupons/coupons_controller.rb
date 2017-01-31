class Coupons::CouponsController < Coupons::ApplicationController
  def index
    paginator = Coupons.configuration.paginator
    @coupons = Coupons::Collection.new(paginator.call(Coupon.order(created_at: :desc), params[:page]))
  end

  def new
    @coupon = Coupon.new
  end

  def create
    @coupon = Coupon.new(coupon_params)

    if @coupon.save
      redirect_to coupons_path,
        notice: t('coupons.flash.coupons.create.notice')
    else
      render :new
    end
  end

  def edit
    @coupon = Coupon.find(params[:id])
  end

  def duplicate
    existing_coupon = Coupon.find(params[:id])
    attributes = existing_coupon.attributes.symbolize_keys.slice(
      :description,
      :valid_from,
      :valid_until,
      :redemption_limit_global,
      :redemption_limit_user,
      :amount,
      :type
    )
    @coupon = Coupon.new(attributes)
    render :new
  end

  def update
    @coupon = Coupon.find(params[:id])

    if @coupon.update(coupon_params)
      redirect_to coupons_path,
        notice: t('coupons.flash.coupons.update.notice')
    else
      render :edit
    end
  end

  def remove
    @coupon = Coupon.find(params[:id])
  end

  def destroy
    @coupon = Coupon.find(params[:id])
    @coupon.destroy!

    redirect_to coupons_path,
      notice: t('coupons.flash.coupons.destroy.notice')
  end

  def apply
    coupon_code = params[:coupon_code].try(:strip)
    user_id = get_current_user.try(:id)
    amount = BigDecimal(params.fetch(:amount, '0.0'))
    options = Coupons
              .apply(coupon_code, amount: amount, user_id: user_id)
              .slice(:amount, :discount, :total, :status)
              .reduce({}) { |buffer, (key, value)|
                value = value.to_f unless key == :status
                buffer.merge(key => value)
              }

    render json: options
  end

  def batch
    if params[:remove_action]
      batch_removal
    else
      redirect_to coupons_path,
        alert: t('coupons.flash.coupons.batch.invalid_action')
    end
  end

  private

  def get_current_user
    main_app.scope.env['warden'].try(:user)
  end

  def batch_removal
    Coupon.where(id: params[:coupon_ids]).destroy_all

    redirect_to coupons_path,
      notice: t('coupons.flash.coupons.batch.removal.notice')
  end

  def coupon_params
    params
      .require(:coupon)
      .permit(
        :code,
        :redemption_limit_global,
        :redemption_limit_user,
        :description,
        :valid_from,
        :valid_until,
        :amount,
        :type
      )
  end
end
