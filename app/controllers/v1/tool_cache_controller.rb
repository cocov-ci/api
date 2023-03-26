# frozen_string_literal: true

module V1
  class ToolCacheController < V1Controller
    before_action :ensure_authentication
    before_action :ensure_service_token
    before_action :require_engine
    before_action :preload_item, only: %i[show delete touch]

    VALID_ORDERS = %w[created_at stale].freeze

    def index
      artifacts = CacheTool.all

      order = params[:order] || "created_at"
      error! :cache, :invalid_order unless VALID_ORDERS.include? order

      artifacts = if order == "created_at"
        artifacts.order(created_at: :desc)
      else
        artifacts.order(:last_used_at)
      end

      render "v1/tool_cache/index", locals: {
        repo: @repo,
        items: paginating(artifacts)
      }
    end

    def show
      render "v1/tool_cache/show", locals: { item: @item }
    end

    def create
      name = params[:name]
      name_hash = params[:name_hash]
      size = params[:size]
      mime = params[:mime]

      error! :cache, :missing_name if name.blank?
      error! :cache, :missing_name_hash if name_hash.blank?
      error! :cache, :missing_size if size.blank?
      error! :cache, :invalid_size unless /\A\d+\z/.match?(size)
      error! :cache, :invalid_size unless size.to_i.positive?
      error! :cache, :missing_mime if mime.blank?

      item = CacheTool.create!(
        name:,
        name_hash:,
        size:,
        mime:,
        engine: @engine,
        last_used_at: Time.zone.now
      )

      render "v1/tool_cache/create", locals: { item: }
    end

    def delete
      @item.destroy

      head :no_content
    end

    def touch
      @item.last_used_at = Time.zone.now
      @item.save!

      head :no_content
    end

    private

    def require_engine
      @engine = params[:engine]
      error! :cache, :missing_engine if @engine.blank?
    end

    def preload_item
      @item = CacheTool.find_by!(name_hash: params[:name_hash], engine: @engine)
    end
  end
end
