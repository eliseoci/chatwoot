import { flushPromises, shallowMount } from '@vue/test-utils';

import PipelineItemsList from '../PipelineItemsList.vue';

const mocks = vi.hoisted(() => ({
  pipelinesGet: vi.fn(),
  agentsGet: vi.fn(),
  itemsGet: vi.fn(),
  transition: vi.fn(),
  updateOwnership: vi.fn(),
  activityCreate: vi.fn(),
  alert: vi.fn(),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    locale: { value: 'en' },
    t: (key, values = {}) =>
      Object.entries(values).reduce(
        (text, [name, value]) => `${text} ${name}:${value}`,
        key
      ),
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: mocks.alert,
}));

vi.mock('dashboard/api/pipelines', () => ({
  default: { get: mocks.pipelinesGet },
}));

vi.mock('dashboard/api/agents', () => ({
  default: { get: mocks.agentsGet },
}));

vi.mock('dashboard/api/pipelineItems', () => ({
  default: {
    get: mocks.itemsGet,
    transition: mocks.transition,
    updateOwnership: mocks.updateOwnership,
    create: vi.fn(),
    linkConversation: vi.fn(),
    unlinkConversation: vi.fn(),
  },
}));

vi.mock('dashboard/api/pipelineActivities', () => ({
  default: { create: mocks.activityCreate },
}));

const pipeline = {
  id: 1,
  name: 'Sales',
  stages: [
    { id: 10, name: 'Qualified' },
    { id: 11, name: 'Proposal' },
  ],
};

const linkedItem = {
  id: 20,
  pipeline_id: 1,
  stage_id: 10,
  display_title: 'Acme renewal',
  owner: { id: 7, available_name: 'Nadia' },
  next_activity: {
    title: 'Call Acme',
    due_at: '2026-06-15T15:00:00.000Z',
  },
};

const mountComponent = async () => {
  const wrapper = shallowMount(PipelineItemsList, {
    props: { conversationId: 42, contactId: 9 },
    global: {
      mocks: {
        $t: key => key,
      },
    },
  });
  await flushPromises();
  return wrapper;
};

describe('PipelineItemsList', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.pipelinesGet.mockResolvedValue({ data: [pipeline] });
    mocks.agentsGet.mockResolvedValue({
      data: [{ id: 7, available_name: 'Nadia' }],
    });
    mocks.itemsGet.mockResolvedValue({
      data: [{ ...linkedItem, owner: { ...linkedItem.owner } }],
    });
    mocks.transition.mockResolvedValue({
      data: { ...linkedItem, stage_id: 11 },
    });
    mocks.updateOwnership.mockResolvedValue({
      data: { ...linkedItem, owner: null },
    });
  });

  it('loads conversation-linked and contact-compatible pipeline items', async () => {
    const wrapper = await mountComponent();

    expect(mocks.itemsGet).toHaveBeenCalledWith({ conversationId: 42 });
    expect(mocks.itemsGet).toHaveBeenCalledWith({ contactId: 9 });
    expect(wrapper.text()).toContain('Acme renewal');
    expect(wrapper.text()).toContain('Call Acme');
  });

  it('changes stage and owner through pipeline domain endpoints', async () => {
    const wrapper = await mountComponent();
    const [stageSelect, ownerSelect] = wrapper.findAll('select');

    await stageSelect.setValue('11');
    expect(mocks.transition).toHaveBeenCalledWith(20, {
      stageId: 11,
      source: 'conversation_sidebar',
    });

    await flushPromises();
    await ownerSelect.setValue('');
    expect(mocks.updateOwnership).toHaveBeenCalledWith(20, {
      ownerId: null,
      source: 'conversation_sidebar',
    });
  });

  it('shows an explicit unavailable state when no pipeline exists', async () => {
    mocks.pipelinesGet.mockResolvedValueOnce({ data: [] });

    const wrapper = await mountComponent();

    expect(wrapper.text()).toContain('PIPELINES_SIDEBAR.NO_PIPELINES');
    expect(wrapper.text()).not.toContain('PIPELINES_SIDEBAR.EMPTY');
  });
});
