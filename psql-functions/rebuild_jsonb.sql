CREATE OR REPLACE FUNCTION public.rebuild_jsonb(flat jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  entry        RECORD;
  result       JSONB := '{}'::jsonb;
  obj_prefixes TEXT[];
  arr_prefixes TEXT[];
  prefix       TEXT;
  path         TEXT[];
BEGIN
  -- 1) Collect all object‐prefixes (e.g. "user", "user.prefs" from "user.prefs.theme")
  SELECT array_agg(DISTINCT regexp_replace(k, '\.[^\.]+$', ''))
    INTO obj_prefixes
  FROM jsonb_object_keys(flat) AS t(k)
  WHERE k LIKE '%.%';

  IF obj_prefixes IS NOT NULL THEN
    FOREACH prefix IN ARRAY obj_prefixes LOOP
      result := jsonb_set(
        result,
        regexp_split_to_array(prefix, '\.'),
        '{}'::jsonb,
        true
      );
    END LOOP;
  END IF;

  -- 2) Collect all array‐prefixes (e.g. "tags" from "tags[0]")
  SELECT array_agg(DISTINCT regexp_replace(k, '\[\d+\].*$', ''))
    INTO arr_prefixes
  FROM jsonb_object_keys(flat) AS t(k)
  WHERE k LIKE '%[%]%';

  IF arr_prefixes IS NOT NULL THEN
    FOREACH prefix IN ARRAY arr_prefixes LOOP
      result := jsonb_set(
        result,
        regexp_split_to_array(prefix, '\.'),
        '[]'::jsonb,
        true
      );
    END LOOP;
  END IF;

  -- 3) Finally, put each flat value into place
  FOR entry IN
    SELECT key, value
      FROM jsonb_each(flat)
  LOOP
    -- turn "a.b[2].c" → ['a','b','2','c']
    path := regexp_split_to_array(
      regexp_replace(entry.key, '\[(\d+)\]', '.\1', 'g'),
      '\.'
    );
    result := jsonb_set(
      result,
      path,
      entry.value,
      true
    );
  END LOOP;

  RETURN result;
END;
$function$
