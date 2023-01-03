# frozen_string_literal: true

module V1
  class SecretsController < V1Controller
    before_action :ensure_authentication

    def index
      render "v1/secrets/index", locals: {
        secrets: paginating(secrets.order(name: :asc))
      }
    end

    def create
      name = params[:name]
      data = params[:data]

      error! :secrets, :missing_name if name.blank?
      error! :secrets, :missing_data if data.blank?

      sec = Secret.new(name:, data:)

      if params[:repo_name]
        repo = Repository
          .find_by!(name: params[:repo_name])

        error! :secrets, :name_taken if repo.secrets.exists?(name:)

        sec.repository = repo
        sec.scope = :repository
      else
        error! :secrets, :name_taken if Secret.exists?(repository: nil, name:)
        sec.scope = :organization
      end

      sec.save!

      render "v1/secrets/create",
        locals: { secret: sec },
        status: :created
    end

    def patch
      data = params[:data]
      error! :secrets, :missing_data if data.blank?

      secret.data = data
      secret.save!

      render "v1/secrets/create",
        locals: { secret: },
        status: :ok
    end

    def delete
      secret.destroy
      head :no_content
    end

    private

    def secret
      @secret ||= secrets.find(params[:id])
    end

    def secrets
      @secrets ||= if params[:repo_name]
                     Repository
                       .find_by!(name: params[:repo_name])
                       .secrets
                   else
                     Secret.where(repository: nil)
                   end
    end
  end
end
