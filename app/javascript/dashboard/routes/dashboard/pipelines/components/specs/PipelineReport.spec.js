import { shallowMount } from '@vue/test-utils';

import PipelineReport from '../PipelineReport.vue';

const report = {
  generated_at: '2026-06-15T12:00:00Z',
  timezone: 'UTC',
  reporting_date: '2026-06-15',
  stages: [
    {
      id: 1,
      name: 'Qualified',
      item_count: 4,
      average_age_seconds: 172800,
      oldest_age_seconds: 432000,
    },
  ],
  outcomes: [
    {
      stage_id: 2,
      stage_name: 'Won',
      outcome_key: 'won',
      item_count: 2,
      reasons: [{ reason: 'Fast implementation', item_count: 2 }],
    },
  ],
  activities: {
    summary: { due: 3, overdue: 1, completed: 5, canceled: 0 },
    owners: [
      {
        assignee_id: 7,
        assignee_name: 'Nadia',
        due: 2,
        overdue: 1,
        completed: 4,
        canceled: 0,
      },
    ],
  },
  attribution: {
    sources: [{ key: 'automation', item_count: 2 }],
    inboxes: [{ id: 9, name: 'Website', item_count: 3 }],
    channels: [{ key: 'Channel::WebWidget', item_count: 3 }],
  },
};

describe('PipelineReport', () => {
  it('renders operational reporting sections from the report contract', () => {
    const wrapper = shallowMount(PipelineReport, {
      props: { report, isLoading: false, loadState: 'ready' },
      global: {
        mocks: { $t: key => key },
      },
    });

    expect(
      wrapper.findAll('[data-testid="pipeline-report-stage"]')
    ).toHaveLength(1);
    expect(wrapper.text()).toContain('Qualified');
    expect(wrapper.text()).toContain('Nadia');
    expect(wrapper.text()).toContain('Won');
    expect(wrapper.text()).toContain('Website');
  });
});
