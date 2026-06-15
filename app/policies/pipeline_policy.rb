class PipelinePolicy < ApplicationPolicy
  def index?
    account_user.present?
  end

  def show?
    access.allowed?(:view)
  end

  def create?
    account_user.administrator?
  end

  def update?
    access.allowed?(:update)
  end

  def archive?
    access.allowed?(:archive)
  end

  def configure?
    access.allowed?(:configure)
  end

  def export?
    access.allowed?(:export)
  end

  def automate?
    access.allowed?(:automate)
  end

  def manage_access?
    access.allowed?(:manage_access)
  end

  def create_item?
    access.allowed?(:create_item)
  end

  def update_item?
    access.allowed?(:update_item)
  end

  def move_item?
    access.allowed?(:move_item)
  end

  def archive_item?
    access.allowed?(:archive_item)
  end

  def templates?
    account_user.administrator?
  end

  def capabilities
    access.capability_map
  end

  private

  def access
    @access ||= Pipelines::Authorization::Access.new(user_context, record)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      Pipelines::Authorization::Access.scope_for(user_context, scope)
    end
  end
end
