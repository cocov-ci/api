module V1
  class RepositorySettingsController < V1Controller
    before_action :ensure_authentication
    before_action :load_repository

    def regen_token
      @repository.token = nil
      @repository.save!

      render json: {
        new_token: @repository.token
      }
    end

    def sync_github
      repo = Cocov::GitHub.app.repo(@repository.github_id)
      @repository.name = repo.name
      @repository.description = repo.description

      name_changed = @repository.name_changed?
      @repository.save!

      if name_changed
        return render json: { new_name: repo.name }
      end

      head :no_content
    end

    def delete
      @repository.destroy
      head :no_content
    end

    private

    def load_repository
      @repository = Repository.find_by! name: params[:name]
    end
  end
end
