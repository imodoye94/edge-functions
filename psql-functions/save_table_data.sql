/********************************************************************
 * CRDT write‑guard – calls Node/Automerge micro‑service
 *******************************************************************/
CREATE OR REPLACE FUNCTION public.crdt_before_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
DECLARE
    _payload      jsonb;
    _endpoint     text;
    _body         text;
    _resp         jsonb;
BEGIN
    /*****  INSERT  *****/
    IF TG_OP = 'INSERT' THEN
        -- If the client already sent a doc we trust it; otherwise create one.
        IF NEW.doc IS NULL OR NEW.doc = '' THEN
            _payload  := to_jsonb(NEW) - ARRAY['doc','modified_at'];          -- strip metadata
            _endpoint := 'http://functions:9033/generateAutoDoc';
            _body     := jsonb_build_object('payload', _payload)::text;

            SELECT content::jsonb INTO _resp
            FROM net.http_post(_endpoint, _body, 'application/json');

            NEW.doc := _resp ->> 'doc';
        END IF;

    /*****  UPDATE  *****/
    ELSIF TG_OP = 'UPDATE' THEN
        -- Build a JSON object of ONLY the fields that changed (excluding doc & modified_at)
        _payload := (to_jsonb(NEW) - ARRAY['doc','modified_at'])
                    #- (to_jsonb(OLD) - ARRAY['doc','modified_at']);

        IF _payload <> '{}'::jsonb THEN
            _endpoint := 'http://functions:9033/mergeAutoDoc';
            _body     := jsonb_build_object(
                            'existing_doc',  OLD.doc,
                            'changes',       _payload
                         )::text;

            SELECT content::jsonb INTO _resp
            FROM net.http_post(_endpoint, _body, 'application/json');

            NEW.doc := _resp ->> 'doc';         -- merged Automerge blob
        ELSE
            -- nothing really changed → keep old doc
            NEW.doc := OLD.doc;
        END IF;
    END IF;

    RETURN NEW;
END;
$func$;
