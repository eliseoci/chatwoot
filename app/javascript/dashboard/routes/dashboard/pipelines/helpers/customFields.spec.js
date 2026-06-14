import {
  buildFieldDefinitionPayload,
  initializeFieldValues,
  transitionMissingFields,
} from './customFields';

describe('pipeline custom field helpers', () => {
  it('builds type-aware definition settings', () => {
    expect(
      buildFieldDefinitionPayload({
        label: ' Segment ',
        fieldType: 'list',
        choices: 'New\nExisting\n',
        currency: '',
      })
    ).toEqual({
      label: 'Segment',
      field_type: 'list',
      settings: { choices: ['New', 'Existing'] },
    });

    expect(
      buildFieldDefinitionPayload({
        label: 'Budget',
        fieldType: 'currency',
        choices: '',
        currency: 'usd',
      })
    ).toEqual({
      label: 'Budget',
      field_type: 'currency',
      settings: { currency: 'USD' },
    });
  });

  it('preserves false values and initializes missing controls', () => {
    const definitions = [
      { key: 'approved', field_type: 'boolean' },
      { key: 'summary', field_type: 'text' },
    ];

    expect(initializeFieldValues(definitions, { approved: false })).toEqual({
      approved: false,
      summary: '',
    });
  });

  it('extracts structured transition requirements', () => {
    const missingFields = [{ key: 'budget', label: 'Budget' }];
    expect(
      transitionMissingFields({
        response: {
          data: {
            error: 'missing_required_fields',
            missing_fields: missingFields,
          },
        },
      })
    ).toEqual(missingFields);
    expect(transitionMissingFields(new Error('network'))).toEqual([]);
  });
});
