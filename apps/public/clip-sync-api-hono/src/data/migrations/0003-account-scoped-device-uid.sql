ALTER TABLE clip_sync_core.device
  DROP CONSTRAINT IF EXISTS uk_device_uid;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'uk_device_account_id_uid_deleted_at'
      AND conrelid = 'clip_sync_core.device'::regclass
  ) THEN
    ALTER TABLE clip_sync_core.device
      ADD CONSTRAINT uk_device_account_id_uid_deleted_at
      UNIQUE (account_id, uid, deleted_at);
  END IF;
END
$$;
