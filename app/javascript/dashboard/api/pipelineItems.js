/* global axios */
import ApiClient from './ApiClient';

class PipelineItemsAPI extends ApiClient {
  constructor() {
    super('pipeline_items', { accountScoped: true });
  }

  get({ pipelineId }) {
    return axios.get(this.url, { params: { pipeline_id: pipelineId } });
  }

  transition(id, { stageId, source }) {
    return axios.patch(`${this.url}/${id}/transition`, {
      transition: {
        stage_id: stageId,
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
