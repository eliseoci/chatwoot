class PipelineItemPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def timeline?
    true
  end

  def transition?
    true
  end
end
