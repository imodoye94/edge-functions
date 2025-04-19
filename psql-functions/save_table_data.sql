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
        -- If the client already sent a doc we trust it; otherwise create one.
        IF NEW.doc IS NULL OR NEW.doc = '' THEN
            _payload  := public.flatten_jsonb(to_jsonb(NEW) - ARRAY['doc','modified_at']);
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
        -- Build a JSON object of ONLY the fields that changed (excluding doc & modified_at)
        _payload := _newload - _oldload;

        /* mark rich‑text paths with a prefix "RT:" */
        FOR _col_name IN
          SELECT column_name
          FROM public.rich_text_columns
          WHERE table_name = TG_TABLE_NAME
        LOOP
            IF _payload ? _col_name THEN
              _payload := jsonb_set(
                            _payload,
                            ARRAY[_col_name],
                            to_jsonb('RT:' || _payload ->> _col_name),
                            false
                          );
            END IF;
        END LOOP;

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
