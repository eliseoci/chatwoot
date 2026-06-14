import { shallowMount } from '@vue/test-utils';

import PipelineWorkspaceToolbar from '../PipelineWorkspaceToolbar.vue';
import { DEFAULT_PIPELINE_FILTERS } from '../../helpers/workspace';

const mountComponent = (props = {}) =>
  shallowMount(PipelineWorkspaceToolbar, {
    props: {
      viewMode: 'kanban',
      filters: { ...DEFAULT_PIPELINE_FILTERS },
      stages: [{ id: 1, name: 'Qualified' }],
      agents: [{ id: 2, available_name: 'Nadia' }],
      teams: [{ id: 3, name: 'Sales' }],
      inboxes: [{ id: 4, name: 'WhatsApp' }],
      labels: [{ id: 5, title: 'vip' }],
      channels: [{ value: 'Channel::Whatsapp', label: 'WhatsApp' }],
      ...props,
    },
    global: {
      mocks: { $t: key => key },
    },
  });

describe('PipelineWorkspaceToolbar', () => {
  it('switches workspace modes', async () => {
    const wrapper = mountComponent();

    await wrapper.findAll('button')[1].trigger('click');

    expect(wrapper.emitted('update:viewMode')).toEqual([['list']]);
  });

  it('emits search and structured filters', async () => {
    const wrapper = mountComponent();

    await wrapper.find('input[type="search"]').setValue('Acme');
    await wrapper.findAll('select')[1].setValue('1');

    expect(wrapper.emitted('update:filters')[0][0]).toEqual({
      ...DEFAULT_PIPELINE_FILTERS,
      q: 'Acme',
    });
    expect(wrapper.emitted('update:filters')[1][0]).toEqual({
      ...DEFAULT_PIPELINE_FILTERS,
      stageId: '1',
    });
  });
});
