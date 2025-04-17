-- in public schema (usable by both mother and child sides) but mostly used by mother VM
CREATE OR REPLACE FUNCTION public.get_box_sync_timestamp(
  _site_id uuid,
  _box_id  uuid
) RETURNS timestamptz
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT (cb ->> 'last_synced_at')::timestamptz
    FROM public.sites,
         jsonb_array_elements(sites.child_boxes) AS cb
   WHERE sites.id    = _site_id
     AND cb ->> 'box_id' = _box_id::text
   LIMIT 1;
$$;
