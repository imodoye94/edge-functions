CREATE OR REPLACE FUNCTION save_table_data()
RETURNS trigger
LANGUAGE plv8
AS $$
  // Cache Automerge once per backend process
  if (!globalThis.Automerge) {
    globalThis.Automerge = require(
      'http://local-fileserver:9033/data/mediverse/scripts/automerge.min.js',
      false
    );
  }
  const Automerge = globalThis.Automerge;

  // Build plain payload from NEW
  const payload = {};
  for (let col in NEW) {
    if (!['id', 'doc', 'created_at', 'modified_at'].includes(col)) {
      payload[col] = NEW[col];
    }
  }

  // Rehydrate previous CRDT (ONLY for UPDATE)
  let doc = (TG_OP === 'UPDATE' && OLD.doc)
    ? Automerge.load(OLD.doc)
    : Automerge.init();

  // Apply the incoming changes in one CRDT transaction
  doc = Automerge.change(doc, d => Object.assign(d, payload));

  // Push values back into NEW
  const exploded = Automerge.toJS(doc);
  for (let col in NEW) {
    if (!['id', 'doc', 'created_at', 'modified_at'].includes(col)
        && exploded[col] !== undefined) {
      NEW[col] = exploded[col];
    }
  }

  // Persist the CRDT
  NEW.doc = Automerge.save(doc);

  return NEW;
$$;
