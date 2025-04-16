CREATE OR REPLACE FUNCTION sync_child(_site_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  site_record RECORD;
  table_names TEXT[];
  tbl          TEXT;
BEGIN
  -- 1) Load and lock this site row
  SELECT *
    INTO site_record
    FROM public.sites
   WHERE id = _site_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'sync_child: site % not found', _site_id;
  END IF;

  -- 2) Find all public tables that have a modified_at column
  SELECT array_agg(table_name::text)
    INTO table_names
    FROM information_schema.columns
   WHERE table_schema = 'public'
     AND column_name = 'modified_at';

  IF table_names IS NULL OR array_length(table_names,1)=0 THEN
    RAISE NOTICE 'sync_child: no tables with modified_at found';
    RETURN;
  END IF;

  -- 3) Loop each table and invoke the child‐side sync
  FOREACH tbl IN ARRAY table_names
  LOOP
    PERFORM start_sync_child(_site_id, tbl);
  END LOOP;

  -- 4) Update sites last_synced_at
  PERFORM sync_site_metadata_update(_site_id);

END;
$$;
