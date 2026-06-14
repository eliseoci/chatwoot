json.array! @transitions do |transition|
  json.id transition.id
  json.source transition.source
  json.created_at transition.created_at
  json.from_stage do
    json.id transition.from_stage.id
    json.name transition.from_stage.name
  end
  json.to_stage do
    json.id transition.to_stage.id
    json.name transition.to_stage.name
  end
  json.actor do
    json.id transition.actor.id
    json.name transition.actor.available_name
  end
end
