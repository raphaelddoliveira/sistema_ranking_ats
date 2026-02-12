import { createClient } from '@supabase/supabase-js';

export default async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const authHeader = req.headers.authorization;
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    const supabase = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY
    );

    // 1. Apply ambulance daily penalties
    const { data: ambulanceCount, error: ambulanceError } =
      await supabase.rpc('apply_ambulance_daily_penalties');

    if (ambulanceError) {
      console.error('apply_ambulance_daily_penalties error:', ambulanceError);
      return res.status(500).json({ error: ambulanceError.message });
    }

    // 2. Apply overdue fee penalties
    const { data: overdueCount, error: overdueError } =
      await supabase.rpc('apply_overdue_penalties');

    if (overdueError) {
      console.error('apply_overdue_penalties error:', overdueError);
      return res.status(500).json({ error: overdueError.message });
    }

    return res.status(200).json({
      success: true,
      ambulance_penalties: ambulanceCount,
      overdue_penalties: overdueCount,
      executed_at: new Date().toISOString(),
    });
  } catch (err) {
    console.error('Unexpected error:', err);
    return res.status(500).json({ error: err.message });
  }
}
