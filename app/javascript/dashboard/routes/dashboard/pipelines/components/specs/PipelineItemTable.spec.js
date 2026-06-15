import { shallowMount } from '@vue/test-utils';

import PipelineItemTable from '../PipelineItemTable.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    locale: { value: 'en' },
    t: key => key,
  }),
}));

const item = {
  id: 1,
  stage_id: 10,
  display_title: 'Acme renewal',
  contact: { name: 'Acme' },
  owner: { name: 'Nadia' },
  team: { name: 'Sales' },
  priority: 'high',
  next_activity: null,
  workspace: {
    last_activity_at: '2026-06-14T12:00:00Z',
    inboxes: [{ id: 4, name: 'WhatsApp' }],
    attention_reasons: ['missing_next_activity'],
  },
};

const mountComponent = () =>
  shallowMount(PipelineItemTable, {
    props: {
      items: [item],
      stages: [
        { id: 10, name: 'Qualified' },
        { id: 11, name: 'Proposal' },
      ],
      canMove: true,
    },
    global: {
      mocks: { $t: key => key },
    },
  });

describe('PipelineItemTable', () => {
  it('supports accessible keyboard opening and stage movement', async () => {
    const wrapper = mountComponent();

    await wrapper.find('tbody tr').trigger('keydown', { key: 'Enter' });
    await wrapper.find('select').setValue('11');

    expect(wrapper.emitted('open')).toEqual([[item]]);
    expect(wrapper.emitted('move')).toEqual([[{ item, stageId: 11 }]]);
  });

  it('renders operational and attention context', () => {
    const wrapper = mountComponent();

    expect(wrapper.text()).toContain('Acme renewal');
    expect(wrapper.text()).toContain('WhatsApp');
    expect(wrapper.text()).toContain(
      'PIPELINES_BOARD.ATTENTION.REASONS.MISSING_NEXT_ACTIVITY'
    );
  });
});
