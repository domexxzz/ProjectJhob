import { Router } from 'express';
import { getPredictions } from './predictions.controller';
import { requireAuth } from '../../lib/auth';

const router = Router();

router.use(requireAuth);

router.get('/', getPredictions);

export const predictionsRouter = router;
