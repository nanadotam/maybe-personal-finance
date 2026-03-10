# frozen_string_literal: true

class Api::V1::CategoriesController < Api::V1::BaseController
  include Pagy::Backend

  before_action :ensure_read_scope
  before_action :set_category, only: :show

  def index
    categories_query = current_resource_owner.family.categories
      .includes(:parent)
      .order(:classification, :name)

    categories_query = categories_query.where(classification: params[:classification]) if params[:classification].present?
    categories_query = categories_query.where(parent_id: params[:parent_id]) if params[:parent_id].present?
    categories_query = categories_query.roots if params[:roots] == "true"

    if params[:search].present?
      search_term = "%#{params[:search]}%"
      categories_query = categories_query.where("categories.name ILIKE ?", search_term)
    end

    @pagy, @categories = pagy(
      categories_query,
      page: safe_page_param,
      limit: safe_per_page_param
    )

    @per_page = safe_per_page_param

    render :index
  rescue => e
    Rails.logger.error "CategoriesController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  def show
    render :show
  rescue => e
    Rails.logger.error "CategoriesController#show error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  private
    def ensure_read_scope
      authorize_scope!(:read)
    end

    def set_category
      @category = current_resource_owner.family.categories.includes(:parent).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Category not found"
      }, status: :not_found
    end

    def safe_page_param
      page = params[:page].to_i
      page > 0 ? page : 1
    end

    def safe_per_page_param
      per_page = params[:per_page].to_i

      case per_page
      when 1..100
        per_page
      else
        25
      end
    end
end
