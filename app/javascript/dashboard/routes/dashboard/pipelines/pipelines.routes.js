import { frontendURL } from '../../../helper/URLHelper';
import PipelinesBoard from './Index.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/pipelines/:pipelineId?'),
    name: 'pipelines_board',
    component: PipelinesBoard,
    meta: {
      permissions: ['administrator', 'agent'],
    },
  },
];
