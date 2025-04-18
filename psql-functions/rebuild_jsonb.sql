CREATE OR REPLACE FUNCTION public.rebuild_jsonb(flat jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
    result     jsonb := '{}'::jsonb;      -- final document

    leaf       RECORD;                    -- loop over key/value pairs
    tokens     text[];                    -- path split into parts
    i          integer;                   -- index in tokens
    subpath    text[];
    nexttok    text;
    container  jsonb;
BEGIN
    --------------------------------------------------------------------------
    -- 1) For every flattened path ⇒ value pair
    --------------------------------------------------------------------------
    FOR leaf IN
        SELECT key, value FROM jsonb_each(flat)
    LOOP
        -- a) split "a.b[0].c" → ['a','b','0','c']
        tokens := regexp_split_to_array(
                    regexp_replace(leaf.key, '\[(\d+)\]', '.\1', 'g'),
                    '\.'
                  );

        -- b) ensure parent containers exist
        IF array_length(tokens,1) > 1 THEN
            FOR i IN 1 .. array_length(tokens,1)-1 LOOP
                subpath := tokens[1:i];

                -- skip if already there
                IF result #> subpath IS NOT NULL THEN
                    CONTINUE;
                END IF;

                -- pick object {} vs array [] based on next token
                nexttok := tokens[i+1];
                container := CASE WHEN nexttok ~ '^\d+$' THEN '[]'::jsonb ELSE '{}'::jsonb END;

                result := jsonb_set(result, subpath, container, true);
            END LOOP;
        END IF;

        -- c) set the leaf value
        result := jsonb_set(result, tokens, leaf.value, true);
    END LOOP;

    --------------------------------------------------------------------------
    -- 2) Post‑process: if top‑level has only a "" key, unwrap it
    --------------------------------------------------------------------------
    IF result ? '' AND
       (SELECT count(*) = 1 FROM jsonb_object_keys(result)) THEN
      RETURN result -> '';
    END IF;

    RETURN result;
END;
$function$
