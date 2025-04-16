CREATE OR REPLACE FUNCTION sync_site_metadata_update(
  _site_id UUID,
  _box_id  UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  site_record RECORD;
BEGIN
  -- 1) Lock and fetch the site row
  SELECT *
    INTO site_record
    FROM public.sites
   WHERE id = _site_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'sync_site_metadata_update: site % not found', _site_id;
  END IF;

  -- 2) Update the top‐level last_synced_at
  UPDATE public.sites
     SET last_synced_at = CURRENT_TIMESTAMP
   WHERE id = _site_id;

  -- 3) If a box_id was provided, update its entry in nexus_boxes
  IF _box_id IS NOT NULL THEN
    UPDATE public.sites
       SET nexus_boxes = (
         SELECT jsonb_agg(
           CASE
             WHEN (elem->>'id')::UUID = _box_id
             THEN jsonb_set(
                    elem,
                    '{last_synced_at}',
                    to_jsonb(CURRENT_TIMESTAMP),
                    false
                  )
             ELSE elem
           END
         )
           FROM jsonb_array_elements(site_record.nexus_boxes) AS x(elem)
       )
     WHERE id = _site_id;
  END IF;
END;
$$;
