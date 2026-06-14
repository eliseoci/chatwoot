export const buildPipelinePayload = ({
  name,
  description,
  templateKey,
  customStages,
}) => {
  const pipeline = {
    name: name.trim(),
    description: description.trim(),
    template_key: templateKey,
  };

  if (templateKey === 'custom') {
    pipeline.stages = customStages
      .split('\n')
      .map(stageName => stageName.trim())
      .filter(Boolean)
      .map(stageName => ({ name: stageName }));
  }

  return { pipeline };
};
