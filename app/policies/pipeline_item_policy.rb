class PipelineItemPolicy < ApplicationPolicy
  def index?
    account_user.present?
  end

  def show?
    pipeline_policy.show?
  end

  def create?
    pipeline_policy.create_item?
  end

  def timeline?
    show?
  end

  def transition?
    pipeline_policy.move_item?
  end

  def ownership?
    pipeline_policy.update_item?
  end

  def field_values?
    pipeline_policy.update_item?
  end

  def linked_conversations?
    show?
  end

  def link_conversation?
    pipeline_policy.update_item?
  end

  def unlink_conversation?
    pipeline_policy.update_item?
  end

  private

  def pipeline_policy
    PipelinePolicy.new(user_context, record.pipeline)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      pipeline_scope = PipelinePolicy::Scope.new(user_context, account.pipelines).resolve
      scope.where(pipeline_id: pipeline_scope.select(:id))
    end
  end
end
