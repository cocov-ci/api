# frozen_string_literal: true

module V1
  class PrivateKeysController < V1Controller
    before_action :ensure_authentication

    def index
      render "v1/private_keys/index", locals: {
        private_keys: paginating(keys.order(name: :asc))
      }
    end

    def create
      name = params[:name]
      key = params[:key]

      error! :private_keys, :missing_name if name.blank?
      error! :private_keys, :missing_key if key.blank?
      error! :private_keys, :invalid_key unless PrivateKey.valid? key

      pkey = PrivateKey.new(name:, key:)

      if params[:repo_name].present?
        repo = Repository.find_by! name: params[:repo_name]
        error! :private_keys, :name_taken if repo.private_keys.exists?(name:)

        pkey.repository = repo
        pkey.scope = :repository
      else
        error! :private_keys, :name_taken if PrivateKey.exists?(repository: nil, name:)
        pkey.scope = :organization
      end

      pkey.save!

      render "v1/private_keys/create",
        locals: { private_key: pkey },
        status: :created
    end

    def delete
      key.destroy
      head :no_content
    end

    private

    def key
      @key ||= keys.find(params[:id])
    end

    def keys
      @keys ||= if params[:repo_name]
                  Repository
                    .find_by!(name: params[:repo_name])
                    .private_keys
                else
                  PrivateKey.where(repository: nil)
                end
    end
  end
end
