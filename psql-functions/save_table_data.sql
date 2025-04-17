CREATE OR REPLACE FUNCTION save_table_data()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  payload      jsonb;
  gen_doc      text;
  merged_doc   text;
  exploded     jsonb;
  http_res     jsonb;
  k            text;
  v            jsonb;
BEGIN
  -- Build the “current row” JSON minus id and doc
  payload := to_jsonb(NEW) - 'id' - 'doc';

  -- 1) Generate a fresh doc from the row’s current values
  SELECT (content::jsonb->>'doc')::text
    INTO gen_doc
    FROM http_post(
           'http://generate-autodoc:8080/generateAutoDoc',
           payload,
           '{}'::jsonb
         ) AS resp(headers jsonb, status_code int, content text);

  -- 2) If NEW.doc was non‑null, merge it in
  IF NEW.doc IS NOT NULL THEN
    SELECT (content::jsonb->>'doc')::text
      INTO merged_doc
      FROM http_post(
             'http://merge-autodoc:8080/mergeAutoDoc',
             jsonb_build_object('doc1', gen_doc, 'doc2', NEW.doc),
             '{}'::jsonb
           ) AS resp(headers jsonb, status_code int, content text);
  ELSE
    merged_doc := gen_doc;
  END IF;

  -- 3) Explode that merged_doc into column‑name → value pairs
  SELECT (content::jsonb->'json_data')
    INTO exploded
    FROM http_post(
           'http://explode-autodoc:8080/explodeAutoDoc',
           jsonb_build_object('doc', merged_doc),
           '{}'::jsonb
         ) AS resp(headers jsonb, status_code int, content text);

  -- 4) Overwrite each field in NEW from the exploded JSON
  FOR k, v IN SELECT * FROM jsonb_each(exploded) LOOP
    -- skip id and doc
    IF k NOT IN ('id','doc') THEN
      EXECUTE format('NEW.%I := $1', k) USING v;
    END IF;
  END LOOP;

  -- 5) Finally set the merged doc
  NEW.doc := merged_doc;

  RETURN NEW;
END;
$$;
