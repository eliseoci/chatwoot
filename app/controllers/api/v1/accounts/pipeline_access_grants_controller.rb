class Api::V1::Accounts::PipelineAccessGrantsController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline
  before_action :authorize_access_management
  before_action :fetch_grant, only: [:update, :destroy]

  def index
    @access_grants = @pipeline.access_grants.includes(:user, :team).order(:created_at, :id)
  end

  def create
    @access_grant = @pipeline.access_grants.new(access_grant_attributes)
    assign_grantee
    @access_grant.save!
  end

  def update
    @access_grant.update!(access_grant_params.permit(:access_level))
  end

  def destroy
    @access_grant.destroy!
    head :no_content
  end

  private

  def fetch_pipeline
    @pipeline = Current.account.pipelines.find(params[:pipeline_id])
  end

  def authorize_access_management
    authorize @pipeline, :manage_access?
  end

  def fetch_grant
    @access_grant = @pipeline.access_grants.find(params[:id])
  end

  def assign_grantee
    @access_grant.user = fetch_user if access_grant_params[:user_id].present?
    @access_grant.team = fetch_team if access_grant_params[:team_id].present?
  end

  def access_grant_attributes
    access_grant_params.permit(:access_level).merge(account: Current.account)
  end

  def access_grant_params
    params.require(:pipeline_access_grant).permit(:user_id, :team_id, :access_level)
  end

  def fetch_user
    Current.account.users.find(access_grant_params[:user_id])
  end

  def fetch_team
    Current.account.teams.find(access_grant_params[:team_id])
  end
end
