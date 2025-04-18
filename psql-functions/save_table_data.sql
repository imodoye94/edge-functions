/********************************************************************
 * CRDT write‑guard – calls Node/Automerge micro‑service via http extension
 *******************************************************************/
CREATE OR REPLACE FUNCTION public.save_table_data()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
DECLARE
    _payload      jsonb;
    _col_name     text;
    _endpoint     text;
    _body         text;
    _resp         jsonb;
    _rich_prefix  text := TG_TABLE_NAME || '.';
    _newload      jsonb := public.flatten_jsonb(to_jsonb(NEW) - ARRAY['doc','modified_at']);
    _oldload      jsonb := public.flatten_jsonb(to_jsonb(OLD) - ARRAY['doc','modified_at']);
BEGIN
    /*****  INSERT  *****/
    IF TG_OP = 'INSERT' THEN
        IF NEW.doc IS NULL OR NEW.doc = '' THEN
            _payload  := _newload;
            _endpoint := 'http://functions-container-lcwscooskc08c8g8sks84sc0:9033/generateAutoDoc';
            _body     := jsonb_build_object('payload', _payload)::text;

            SELECT content::jsonb
              INTO _resp
            FROM http_post(
              _endpoint,
              _body,
              'application/json'
            );

            NEW.doc := _resp ->> 'doc';
        END IF;

    /*****  UPDATE  *****/
    ELSIF TG_OP = 'UPDATE' THEN
        -- Build a JSON object of ONLY the fields that changed
        SELECT jsonb_object_agg(key, val)
          INTO _payload
        FROM (
          SELECT key, val
          FROM jsonb_each(_newload) AS t(key,val)
          WHERE ( _oldload -> key ) IS DISTINCT FROM val
        ) sub;

        /* mark rich‑text columns by key rename */
        IF _payload IS NOT NULL THEN
          FOR _col_name IN
            SELECT column_name
            FROM public.rich_text_columns
            WHERE table_name = TG_TABLE_NAME
          LOOP
            IF _payload ? _col_name THEN
              _payload :=
                jsonb_strip_nulls( (_payload - _col_name)
                  || jsonb_build_object(
                       'RT:'||_col_name, _payload -> _col_name ) );
            END IF;
          END LOOP;
        ELSE
          _payload := '{}'::jsonb;
        END IF;

        IF _payload <> '{}'::jsonb THEN
            _endpoint := 'http://functions-container-lcwscooskc08c8g8sks84sc0:9033/mergeAutoDoc';
            _body     := jsonb_build_object(
                            'existing_doc', OLD.doc,
                            'changes',      _payload
                         )::text;

            SELECT content::jsonb
              INTO _resp
            FROM http_post(
              _endpoint,
              _body,
              'application/json'
            );

            NEW.doc := _resp ->> 'doc';
        ELSE
            -- nothing really changed → keep old doc
            NEW.doc := OLD.doc;
        END IF;
    END IF;

    RETURN NEW;
END;
$func$;
