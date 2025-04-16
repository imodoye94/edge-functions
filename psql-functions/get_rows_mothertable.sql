CREATE OR REPLACE FUNCTION public.get_rows_mothertable(
  _site_id   UUID,
  _table_name TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  site_rec    RECORD;
  out_payload JSONB;
  dyn_sql     TEXT;
BEGIN
  -- 1) load the site record (to get last_synced_at)
  SELECT last_synced_at
    INTO site_rec
    FROM public.sites
   WHERE id = _site_id;

  IF NOT FOUND THEN
    -- no such site → return empty array
    RETURN '[]'::jsonb;
  END IF;

  -- 2) build and run dynamic query against public.<table_name>
  dyn_sql := format($f$
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'id', id,
            'doc', doc
          )
        ), '[]'::jsonb
      )
        FROM public.%I
       WHERE modified_at > $1
  $f$, _table_name);

  EXECUTE dyn_sql
    INTO out_payload
    USING site_rec.last_synced_at;

  RETURN out_payload;
END;
$$;
