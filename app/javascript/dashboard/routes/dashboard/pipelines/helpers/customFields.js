export const buildFieldDefinitionPayload = ({
  label,
  fieldType,
  choices,
  currency,
}) => {
  const settings = {};
  if (fieldType === 'list') {
    settings.choices = choices
      .split('\n')
      .map(choice => choice.trim())
      .filter(Boolean);
  }
  if (fieldType === 'currency') {
    settings.currency = currency.trim().toUpperCase();
  }

  return {
    label: label.trim(),
    field_type: fieldType,
    settings,
  };
};

export const initializeFieldValues = (definitions, fieldValues = {}) =>
  definitions.reduce((values, definition) => {
    const value = fieldValues[definition.key];
    values[definition.key] = value ?? '';
    return values;
  }, {});

export const transitionMissingFields = error =>
  error?.response?.data?.error === 'missing_required_fields'
    ? error.response.data.missing_fields || []
    : [];
