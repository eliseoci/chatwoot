class PipelinePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    account_user.administrator?
  end

  def templates?
    account_user.administrator?
  end
end
