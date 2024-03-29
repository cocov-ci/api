# frozen_string_literal: true

module V1
  class SecretsController < V1Controller
    before_action :ensure_authentication
    before_action :ensure_service_token, only: :show

    def index
      render "v1/secrets/index", locals: {
        secrets: paginating(secrets.order(name: :asc))
      }
    end

    def show
      authorization = params[:authorization]
      not_found! if authorization.empty?
      error! :secrets, :invalid_authorization unless authorization.start_with? "csa_"
      secret = Secret.from_authorization(authorization)
      error! :secrets, :invalid_authorization if secret.nil?
      secret.last_used_at = Time.current
      secret.save
      render plain: secret.data
    end

    def create
      name = params[:name]&.strip
      data = params[:data]

      error! :secrets, :missing_name if name.blank?
      error! :secrets, :missing_data if data.blank?
      error! :secrets, :invalid_name unless Secret::NAME_FORMAT_PATTERN.match?(name)

      sec = Secret.new(name:, data:, owner: @user)

      if params[:repo_name]
        repo = Repository
          .with_context(auth_context)
          .find_by!(name: params[:repo_name])

        error! :secrets, :name_taken if repo.secrets.exists?(name:)

        sec.repository = repo
        sec.scope = :repository
      else
        ensure_administrative_privileges
        error! :secrets, :name_taken if Secret.exists?(repository: nil, name:)
        sec.scope = :organization
      end

      sec.save!

      render "v1/secrets/create",
        locals: { secret: sec },
        status: :created
    end

    def patch
      ensure_administrative_privileges if params[:repo_name].blank?

      data = params[:data]
      error! :secrets, :missing_data if data.blank?

      secret.data = data
      secret.save!

      render "v1/secrets/create",
        locals: { secret: },
        status: :ok
    end

    def delete
      ensure_administrative_privileges if params[:repo_name].blank?

      secret.destroy
      head :no_content
    end

    def check_name
      name = params[:name]&.strip
      error! :secrets, :missing_name if name.blank?
      error! :secrets, :invalid_name unless Secret::NAME_FORMAT_PATTERN.match?(name)

      repo = (Repository.with_context(auth_context).find_by!(name: params[:repo_name]) if params[:repo_name].present?)

      render json: { status: Secret.check_name(name, repo:) }
    end

    private

    def secret
      @secret ||= secrets.find(params[:id])
    end

    def secrets
      secrets ||= if params[:repo_name]
        Repository
          .with_context(auth_context)
          .find_by!(name: params[:repo_name])
          .secrets
      else
        Secret.where(repository: nil)
      end
      @secrets = secrets.includes(:owner)
    end
  end
end
