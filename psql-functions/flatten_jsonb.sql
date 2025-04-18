CREATE OR REPLACE FUNCTION public.flatten_jsonb(input jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
WITH RECURSIVE walker(path, value) AS (
  -- 1) seed from top‑level object
  SELECT
    key,
    value
  FROM jsonb_each(input)
  WHERE jsonb_typeof(input) = 'object'

  UNION ALL

  -- 2) seed from top‑level array
  SELECT
    '['||(idx - 1)||']' AS key,
    elem            AS value
  FROM jsonb_array_elements(input) WITH ORDINALITY AS arr(elem, idx)
  WHERE jsonb_typeof(input) = 'array'

  UNION ALL

  -- 3) recurse into any object or array
  SELECT
    CASE
      WHEN sub.key LIKE '[%' THEN w.path || sub.key
      WHEN w.path = ''        THEN sub.key
      ELSE w.path || '.' || sub.key
    END AS path,
    sub.value
  FROM walker AS w
  CROSS JOIN LATERAL (
    -- a) expand array elements
    SELECT
      '['||(idx - 1)||']' AS key,
      elem                  AS value
    FROM jsonb_array_elements(w.value) WITH ORDINALITY AS arr(elem, idx)
    WHERE jsonb_typeof(w.value) = 'array'

    UNION ALL

    -- b) expand object fields
    SELECT
      key,
      value
    FROM jsonb_each(w.value)
    WHERE jsonb_typeof(w.value) = 'object'
  ) AS sub(key, value)  -- <–– here we force the column names to (key,value)
  WHERE jsonb_typeof(w.value) IN ('object','array')
)
SELECT
  COALESCE(
    -- only include leaves (no nested object/array values)
    jsonb_object_agg(path, value)
      FILTER (WHERE jsonb_typeof(value) NOT IN ('object','array')),
    '{}'::jsonb
  )
FROM walker;
$function$
