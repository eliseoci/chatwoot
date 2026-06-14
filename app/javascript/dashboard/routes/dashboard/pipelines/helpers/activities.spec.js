import { buildPipelineActivityPayload, sortActivities } from './activities';

describe('#buildPipelineActivityPayload', () => {
  it('normalizes the scheduled instant and clears empty optional values', () => {
    expect(
      buildPipelineActivityPayload({
        activityType: 'call',
        title: ' Follow up ',
        dueAt: '2026-06-15T09:30',
        assigneeId: '',
        notes: ' ',
      })
    ).toEqual({
      pipeline_activity: {
        activity_type: 'call',
        title: 'Follow up',
        due_at: new Date('2026-06-15T09:30').toISOString(),
        assignee_id: null,
        notes: null,
        source: 'item_detail',
      },
    });
  });
});

describe('#sortActivities', () => {
  it('keeps scheduled work first and orders it by due time', () => {
    const activities = [
      { id: 1, status: 'completed', due_at: '2026-06-14T10:00:00Z' },
      { id: 2, status: 'scheduled', due_at: '2026-06-15T10:00:00Z' },
      { id: 3, status: 'scheduled', due_at: '2026-06-14T11:00:00Z' },
    ];

    expect(sortActivities(activities).map(activity => activity.id)).toEqual([
      3, 2, 1,
    ]);
  });
});
