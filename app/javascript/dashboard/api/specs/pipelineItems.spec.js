import pipelineItemsAPI from '../pipelineItems';
import ApiClient from '../ApiClient';

describe('#PipelineItemsAPI', () => {
  it('creates an account-scoped API client', () => {
    expect(pipelineItemsAPI).toBeInstanceOf(ApiClient);
    expect(pipelineItemsAPI).toHaveProperty('get');
    expect(pipelineItemsAPI).toHaveProperty('show');
    expect(pipelineItemsAPI).toHaveProperty('create');
  });

  it('filters items by pipeline', () => {
    const originalAxios = window.axios;
    const axiosMock = { get: vi.fn(() => Promise.resolve()) };
    window.axios = axiosMock;

    pipelineItemsAPI.get({ pipelineId: 7 });

    expect(axiosMock.get).toHaveBeenCalledWith(pipelineItemsAPI.url, {
      params: { pipeline_id: 7 },
    });
    window.axios = originalAxios;
  });

  it('filters items by contact or linked conversation', () => {
    const originalAxios = window.axios;
    const axiosMock = { get: vi.fn(() => Promise.resolve()) };
    window.axios = axiosMock;

    pipelineItemsAPI.get({ contactId: 8, conversationId: 12 });

    expect(axiosMock.get).toHaveBeenCalledWith(pipelineItemsAPI.url, {
      params: {
        contact_id: 8,
        conversation_id: 12,
      },
    });
    window.axios = originalAxios;
  });

  it('updates item ownership', () => {
    const originalAxios = window.axios;
    const axiosMock = { patch: vi.fn(() => Promise.resolve()) };
    window.axios = axiosMock;

    pipelineItemsAPI.updateOwnership(4, {
      ownerId: 9,
      source: 'conversation_sidebar',
    });

    expect(axiosMock.patch).toHaveBeenCalledWith(
      `${pipelineItemsAPI.url}/4/ownership`,
      {
        ownership: {
          owner_id: 9,
          source: 'conversation_sidebar',
        },
      }
    );
    window.axios = originalAxios;
  });

  it('moves an item through the transition endpoint', () => {
    const originalAxios = window.axios;
    const axiosMock = { patch: vi.fn(() => Promise.resolve()) };
    window.axios = axiosMock;

    pipelineItemsAPI.transition(4, {
      stageId: 9,
      source: 'board_command',
    });

    expect(axiosMock.patch).toHaveBeenCalledWith(
      `${pipelineItemsAPI.url}/4/transition`,
      {
        transition: {
          stage_id: 9,
          source: 'board_command',
        },
      }
    );
    window.axios = originalAxios;
  });

  it('loads the item timeline', () => {
    const originalAxios = window.axios;
    const axiosMock = { get: vi.fn(() => Promise.resolve()) };
    window.axios = axiosMock;

    pipelineItemsAPI.timeline(4);

    expect(axiosMock.get).toHaveBeenCalledWith(
      `${pipelineItemsAPI.url}/4/timeline`
    );
    window.axios = originalAxios;
  });

  it('loads linked conversation summaries', () => {
    const originalAxios = window.axios;
    const axiosMock = { get: vi.fn(() => Promise.resolve()) };
    window.axios = axiosMock;

    pipelineItemsAPI.linkedConversations(4);

    expect(axiosMock.get).toHaveBeenCalledWith(
      `${pipelineItemsAPI.url}/4/linked_conversations`
    );
    window.axios = originalAxios;
  });

  it('links a conversation', () => {
    const originalAxios = window.axios;
    const axiosMock = { post: vi.fn(() => Promise.resolve()) };
    window.axios = axiosMock;

    pipelineItemsAPI.linkConversation(4, {
      conversationId: 12,
      source: 'item_detail',
    });

    expect(axiosMock.post).toHaveBeenCalledWith(
      `${pipelineItemsAPI.url}/4/link_conversation`,
      {
        conversation_link: {
          conversation_id: 12,
          source: 'item_detail',
        },
      }
    );
    window.axios = originalAxios;
  });

  it('unlinks a conversation', () => {
    const originalAxios = window.axios;
    const axiosMock = { delete: vi.fn(() => Promise.resolve()) };
    window.axios = axiosMock;

    pipelineItemsAPI.unlinkConversation(4, {
      conversationId: 12,
      source: 'item_detail',
    });

    expect(axiosMock.delete).toHaveBeenCalledWith(
      `${pipelineItemsAPI.url}/4/unlink_conversation`,
      {
        data: {
          conversation_link: {
            conversation_id: 12,
            source: 'item_detail',
          },
        },
      }
    );
    window.axios = originalAxios;
  });
});
