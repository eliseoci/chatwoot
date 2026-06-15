module Pipelines::Authorization::ItemControllerSupport
  extend ActiveSupport::Concern

  included do
    before_action :fetch_pipeline_item,
                  only: [
                    :show,
                    :timeline,
                    :ownership,
                    :linked_conversations,
                    :link_conversation,
                    :unlink_conversation
                  ]
    before_action :authorize_collection, only: [:index]
    before_action :authorize_pipeline_item,
                  only: [
                    :show,
                    :timeline,
                    :ownership,
                    :linked_conversations,
                    :link_conversation,
                    :unlink_conversation
                  ]
  end

  private

  def fetch_pipeline_item
    @pipeline_item = pipeline_items_scope.find(params[:id])
  end

  def authorize_collection
    authorize PipelineItem, :index?
  end

  def authorize_pipeline_item
    authorize @pipeline_item, authorization_queries.fetch(action_name.to_sym)
  end

  def authorization_queries
    {
      show: :show?,
      timeline: :timeline?,
      ownership: :ownership?,
      linked_conversations: :linked_conversations?,
      link_conversation: :link_conversation?,
      unlink_conversation: :unlink_conversation?
    }
  end
end
