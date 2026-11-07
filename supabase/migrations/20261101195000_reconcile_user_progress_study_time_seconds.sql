-- Reconcile hosted drift: production's public.user_progress predates the
-- 20241228000000 baseline (created with IF NOT EXISTS) and never received
-- study_time_seconds, which 20261101200000's study_progress view and the app
-- require. No-op on databases built from the migration chain.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'user_progress'
      AND column_name = 'study_time_seconds'
  ) THEN
    ALTER TABLE public.user_progress ADD COLUMN study_time_seconds integer DEFAULT 0;
    UPDATE public.user_progress
    SET study_time_seconds = COALESCE(study_time_minutes, 0) * 60;
  END IF;
END
$$;
