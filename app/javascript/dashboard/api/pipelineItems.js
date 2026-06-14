/* global axios */
import ApiClient from './ApiClient';

class PipelineItemsAPI extends ApiClient {
  constructor() {
    super('pipeline_items', { accountScoped: true });
  }

  get({ pipelineId, contactId, conversationId } = {}) {
    const params = {};
    if (pipelineId) params.pipeline_id = pipelineId;
    if (contactId) params.contact_id = contactId;
    if (conversationId) params.conversation_id = conversationId;
    return axios.get(this.url, { params });
  }

  transition(id, { stageId, source }) {
    return axios.patch(`${this.url}/${id}/transition`, {
      transition: {
        stage_id: stageId,
        source,
      },
    });
  }

  updateOwnership(id, { ownerId, source }) {
    return axios.patch(`${this.url}/${id}/ownership`, {
      ownership: {
        owner_id: ownerId,
        source,
      },
    });
  }

  timeline(id) {
    return axios.get(`${this.url}/${id}/timeline`);
  }

  linkedConversations(id) {
    return axios.get(`${this.url}/${id}/linked_conversations`);
  }

  linkConversation(id, { conversationId, source }) {
    return axios.post(`${this.url}/${id}/link_conversation`, {
      conversation_link: {
        conversation_id: conversationId,
        source,
      },
    });
  }

  unlinkConversation(id, { conversationId, source }) {
    return axios.delete(`${this.url}/${id}/unlink_conversation`, {
      data: {
        conversation_link: {
          conversation_id: conversationId,
          source,
        },
      },
    });
  }
}

export default new PipelineItemsAPI();
