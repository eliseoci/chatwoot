class AddPipelineItemOwnershipEvents < ActiveRecord::Migration[7.1]
  def change
    remove_check_constraint :pipeline_item_events, name: 'pipeline_item_events_type_range'
    add_check_constraint :pipeline_item_events,
                         'event_type BETWEEN 0 AND 9',
                         name: 'pipeline_item_events_type_range'
  end
end
