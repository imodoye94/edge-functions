-- 1) Create the trigger function
CREATE OR REPLACE FUNCTION save_table_data()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  payload   JSONB;
  resp      JSONB;
  gen_doc   TEXT;
  merged_doc TEXT;
BEGIN
  -- Only act on INSERT or UPDATE
  IF TG_OP NOT IN ('INSERT','UPDATE') THEN
    RETURN NEW;
  END IF;

  -- Build payload to first call generate-autodoc
  -- strip out id and doc fields from NEW
  payload := jsonb_build_object(
    'json_data', to_jsonb(NEW) - 'id' - 'doc',
    'old_doc',   COALESCE(OLD.doc, NULL)
  );

  -- Call generate-autodoc
  resp := (
    SELECT (content::jsonb)
      FROM http_post(
        'http://generate-autodoc:8080/generateAutoDoc',
        payload,
        NULL::JSONB,     -- no extra headers
        NULL::JSONB      -- no extra params
      )
  );
  gen_doc := resp ->> 'doc';

  IF NEW.doc IS NOT NULL THEN
    -- merge generated doc with existing NEW.doc
    payload := jsonb_build_object(
      'doc1', gen_doc,
      'doc2', NEW.doc
    );

    resp := (
      SELECT (content::jsonb)
        FROM http_post(
          'http://merge-autodoc:8080/mergeAutoDoc',
          payload,
          NULL::JSONB,
          NULL::JSONB
        )
    );
    merged_doc := resp ->> 'doc';
    NEW.doc := merged_doc;
  ELSE
    -- no previous NEW.doc, so just use the generated one
    NEW.doc := gen_doc;
  END IF;

  RETURN NEW;
END;
$$;

-- 2) Attach it to a table (example for "my_table"):
CREATE TRIGGER trg_save_my_table_data
BEFORE INSERT OR UPDATE ON public.my_table
FOR EACH ROW
EXECUTE FUNCTION save_table_data();
