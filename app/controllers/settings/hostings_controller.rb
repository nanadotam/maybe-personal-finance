class Settings::HostingsController < ApplicationController
  layout "settings"

  guard_feature unless: -> { self_hosted? }

  before_action :ensure_admin, only: :clear_cache

  def show
<<<<<<< HEAD
    synth_provider = Provider::Registry.get_provider(:synth)
    @synth_usage = synth_provider&.usage
=======
    synth_provider = Provider::Registry.get_provider(:synth) rescue nil
    @synth_usage = synth_provider&.usage

    exchangerate_provider = Provider::Registry.get_provider(:exchangerate_api) rescue nil
    @exchangerate_usage = exchangerate_provider&.usage

    fmp_provider = Provider::Registry.get_provider(:financial_modeling_prep) rescue nil
    @fmp_usage = fmp_provider&.usage
>>>>>>> 6b5cab33 (Initial commit)
  end

  def update
    if hosting_params.key?(:require_invite_for_signup)
      Setting.require_invite_for_signup = hosting_params[:require_invite_for_signup]
    end

    if hosting_params.key?(:require_email_confirmation)
      Setting.require_email_confirmation = hosting_params[:require_email_confirmation]
    end

    if hosting_params.key?(:synth_api_key)
      Setting.synth_api_key = hosting_params[:synth_api_key]
    end

<<<<<<< HEAD
=======
    if hosting_params.key?(:exchangerate_api_key)
      Setting.exchangerate_api_key = hosting_params[:exchangerate_api_key]
    end

    if hosting_params.key?(:fmp_api_key)
      Setting.fmp_api_key = hosting_params[:fmp_api_key]
    end

>>>>>>> 6b5cab33 (Initial commit)
    redirect_to settings_hosting_path, notice: t(".success")
  rescue ActiveRecord::RecordInvalid => error
    flash.now[:alert] = t(".failure")
    render :show, status: :unprocessable_entity
  end

  def clear_cache
    DataCacheClearJob.perform_later(Current.family)
    redirect_to settings_hosting_path, notice: t(".cache_cleared")
  end

  private
    def hosting_params
<<<<<<< HEAD
      params.require(:setting).permit(:require_invite_for_signup, :require_email_confirmation, :synth_api_key)
=======
      params.require(:setting).permit(:require_invite_for_signup, :require_email_confirmation, :synth_api_key, :exchangerate_api_key, :fmp_api_key)
>>>>>>> 6b5cab33 (Initial commit)
    end

    def ensure_admin
      redirect_to settings_hosting_path, alert: t(".not_authorized") unless Current.user.admin?
    end
end
