class PipelineStagePolicy < ApplicationPolicy
  def update?
    account_user.administrator?
  end
end
