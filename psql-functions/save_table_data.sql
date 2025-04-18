CREATE OR REPLACE FUNCTION save_table_data()
RETURNS trigger
LANGUAGE plv8
AS $$
  /* 1) Lazy‑load Automerge once per Postgres worker */
  if (!globalThis.Automerge) {
    globalThis.Automerge = require(
      'http://local-fileserver:9033/data/mediverse/scripts/automerge.min.js',
      false
    );
  }
  const Automerge = globalThis.Automerge;

  /* 2) Cache the list of JSONB columns for this table */
  if (!globalThis._jsonbCols || globalThis._lastTable !== TG_TABLE_NAME) {
    globalThis._lastTable = TG_TABLE_NAME;
    const cols = sql(`
      SELECT column_name
        FROM information_schema.columns
       WHERE table_schema = current_schema()
         AND table_name   = $1
         AND data_type    = 'jsonb'
    `, [TG_TABLE_NAME]);
    globalThis._jsonbCols = cols.map(r => r.column_name);
  }
  const jsonbCols = globalThis._jsonbCols;

  /* 3) Build the merge payload */
  const payload = {};

  /* 3a) Flatten each JSONB column into { leafPath: value } */
  for (const col of jsonbCols) {
    const val = NEW[col];
    if (val !== null && val !== undefined) {
      const flat = sql(
        `SELECT public.flatten_jsonb($1::jsonb) AS f`,
        [val]
      )[0].f;
      for (const leaf in flat) {
        // e.g. leaf = "[0].x" or "a.b"
        const key = leaf.startsWith('[')
          ? `${col}${leaf}`
          : `${col}.${leaf}`;
        payload[key] = flat[leaf];
      }
    }
  }

  /* 3b) Include all other non‑CRDT, non‑JSONB columns */
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

  /* 4) Rehydrate or init the Automerge doc */
  let doc = (TG_OP === 'UPDATE' && OLD.doc)
    ? Automerge.load(OLD.doc)
    : Automerge.init();

  /* 5) Apply one atomic change with our full payload */
  doc = Automerge.change(doc, d => Object.assign(d, payload));

  /* 6) Explode back into plain JS object */
  const exploded = Automerge.toJS(doc);

  /* 7) Rebuild each JSONB column from exploded leaves */
  for (const col of jsonbCols) {
    const slice = {};
    const p1 = `${col}.`;
    const p2 = `${col}[`;
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

  /* 8) Write back all primitive columns */
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

  /* 9) Persist merged CRDT */
  NEW.doc = Automerge.save(doc);

  return NEW;
$$;
