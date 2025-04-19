CREATE OR REPLACE FUNCTION save_table_data()
RETURNS trigger
LANGUAGE plv8
AS $$
  /* 1) Discover and cache JSONB columns for this table */
  if (!globalThis._jsonbCols || globalThis._lastTable !== TG_TABLE_NAME) {
    globalThis._lastTable   = TG_TABLE_NAME;
    const cols               = sql(`
      SELECT column_name
        FROM information_schema.columns
       WHERE table_schema = current_schema()
         AND table_name   = $1
         AND data_type    = 'jsonb'
    `, [TG_TABLE_NAME]);
    globalThis._jsonbCols    = cols.map(r => r.column_name);
  }
  const jsonbCols = globalThis._jsonbCols;

  /* 2) Build the flat payload of leaf‑paths → values */
  const payload = {};

  /* 2a) Flatten each JSONB column via flatten_jsonb() */
  for (const col of jsonbCols) {
    const val = NEW[col];
    if (val !== null && val !== undefined) {
      const flat = sql(
        `SELECT public.flatten_jsonb($1::jsonb) AS f`,
        [val]
      )[0].f;
      for (const leaf in flat) {
        /* leaf is like "[0].x" or "a.b" */
        const key = leaf.startsWith('[')
          ? `${col}${leaf}`
          : `${col}.${leaf}`;
        payload[key] = flat[leaf];
      }
    }
  }

  /* 2b) Include all other scalar columns (skip id/doc/timestamps/JSONB) */
  for (const col in NEW) {
    if (
      col === 'id' ||
      col === 'doc' ||
      col === 'created_at' ||
      col === 'modified_at' ||
      jsonbCols.includes(col)
    ) continue;
    payload[col] = NEW[col];
  }

  /* 3) Call generateAutoDoc to get a new CRDT blob (base64) */
  const genRes = sql(`
    SELECT content->>'doc' AS doc
      FROM http_post(
             'http://functions-container:8080/generateAutoDoc',
             $1::jsonb,
             '{}'::jsonb
           ) AS resp(headers jsonb, status_code int, content jsonb)
  `, [payload]);
  const newDoc = genRes[0].doc;
  let mergedDoc = newDoc;

  /* 4) On UPDATE, merge with existing OLD.doc */
  if (TG_OP === 'UPDATE' && OLD.doc) {
    const mergeRes = sql(`
      SELECT content->>'doc' AS doc
        FROM http_post(
               'http://functions-container:8080/mergeAutoDoc',
               $1::jsonb,
               '{}'::jsonb
             ) AS resp(headers jsonb, status_code int, content jsonb)
    `, [{ doc1: newDoc, doc2: OLD.doc }]);
    mergedDoc = mergeRes[0].doc;
  }

  /* 5) Explode the merged CRDT back into a plain key→value map */
  const explRes = sql(`
    SELECT content->'json_data' AS data
      FROM http_post(
             'http://functions-container:8080/explodeAutoDoc',
             $1::jsonb,
             '{}'::jsonb
           ) AS resp(headers jsonb, status_code int, content jsonb)
  `, [{ doc: mergedDoc }]);
  const exploded = explRes[0].data;

  /* 6) Rebuild each JSONB column from its exploded leaves */
  for (const col of jsonbCols) {
    const slice = {};
    const p1 = `${col}.`, p2 = `${col}[`;
    for (const k in exploded) {
      if (k.startsWith(p1) || k.startsWith(p2)) {
        const leafKey = k.startsWith(p1)
          ? k.slice(p1.length)
          : k.slice(col.length);
        slice[leafKey] = exploded[k];
      }
    }
    if (Object.keys(slice).length) {
      const rebuilt = sql(
        `SELECT public.rebuild_jsonb($1::jsonb) AS r`,
        [slice]
      )[0].r;
      NEW[col] = rebuilt;
    }
  }

  /* 7) Write back all other primitive columns */
  for (const col in NEW) {
    if (
      col === 'id' ||
      col === 'doc' ||
      col === 'created_at' ||
      col === 'modified_at' ||
      jsonbCols.includes(col)
    ) continue;
    if (exploded[col] !== undefined) {
      NEW[col] = exploded[col];
    }
  }

  /* 8) Persist the final merged CRDT blob */
  NEW.doc = mergedDoc;

  return NEW;
$$;
