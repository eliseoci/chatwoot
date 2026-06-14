class PipelineActivityPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    true
  end

  def update?
    true
  end

  def complete?
    true
  end

  def cancel?
    true
  end
end
