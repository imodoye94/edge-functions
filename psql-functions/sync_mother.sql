CREATE OR REPLACE FUNCTION sync_mother(_site_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  site_record   RECORD;
  table_names   TEXT[];
  box            RECORD;
  tbl            TEXT;
BEGIN
  -- 1) Load site row
  SELECT *
    INTO site_record
    FROM public.sites
   WHERE id = _site_id
   FOR UPDATE;  -- optionally lock so no concurrent syncs

  IF NOT FOUND THEN
    RAISE EXCEPTION 'sync_mother: site % not found', _site_id;
  END IF;

  -- 2) Find all public tables that have a modified_at column
  SELECT array_agg(table_name::text)
    INTO table_names
    FROM information_schema.columns
   WHERE table_schema = 'public'
     AND column_name = 'modified_at';

  IF table_names IS NULL OR array_length(table_names,1)=0 THEN
    RAISE NOTICE 'sync_mother: no tables with modified_at found';
    RETURN;
  END IF;

  -- 3) Loop over each nexus_box (sorted by last_synced_at desc)
  FOR box IN
    SELECT
      (jb ->> 'id')::UUID   AS box_id,
      (jb ->> 'last_synced_at')::timestamptz AS last_sync
    FROM jsonb_array_elements(site_record.nexus_boxes) AS x(jb)
    ORDER BY last_sync DESC
  LOOP
    -- 4) For each table, kick off the per‑table sync
    FOREACH tbl IN ARRAY table_names
    LOOP
      PERFORM start_sync_mothertable(_site_id, tbl, box.box_id);
    END LOOP;

    -- 5) Update the site_record.last_synced_at for this box
    PERFORM sync_site_metadata_update(_site_id, box.box_id);
  END LOOP;
END;
$$;
