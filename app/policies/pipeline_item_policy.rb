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

  def linked_conversations?
    true
  end

  def link_conversation?
    true
  end

  def unlink_conversation?
    true
  end
end
