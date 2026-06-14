import { mount } from '@vue/test-utils';

import PipelineItemDetails from '../PipelineItemDetails.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    locale: { value: 'en' },
    t: key => key,
  }),
}));

const mountComponent = () =>
  mount(PipelineItemDetails, {
    props: {
      item: {
        id: 1,
        stage_id: 2,
        display_title: 'Acme renewal',
        contact: { name: 'Acme' },
        field_values: { approved: false },
        linked_conversations: [],
      },
      fieldDefinitions: [
        {
          id: 10,
          key: 'summary',
          label: 'Summary',
          field_type: 'text',
          settings: {},
          updated_at: '2026-06-14T12:00:00Z',
        },
        {
          id: 11,
          key: 'approved',
          label: 'Approved',
          field_type: 'boolean',
          settings: {},
          updated_at: '2026-06-14T12:00:00Z',
        },
      ],
      requiredFieldKeys: ['summary'],
    },
    global: {
      mocks: { $t: key => key },
      stubs: {
        Teleport: true,
        Button: {
          props: ['label'],
          template: '<button type="submit">{{ label }}</button>',
        },
        Icon: true,
        Input: true,
        TextArea: true,
      },
    },
  });

describe('PipelineItemDetails custom fields', () => {
  it('edits typed values and preserves false boolean values', async () => {
    const wrapper = mountComponent();

    await wrapper
      .find('input[type="text"]')
      .setValue('Decision maker confirmed');
    await wrapper.find('form').trigger('submit');

    expect(wrapper.text()).toContain('PIPELINES_BOARD.FIELDS.REQUIRED');
    expect(wrapper.emitted('save-field-values')).toEqual([
      [
        {
          summary: 'Decision maker confirmed',
          approved: false,
        },
      ],
    ]);
  });
});
