const functions = require('@google-cloud/functions-framework');
const Automerge = require('@automerge/automerge');

// Local function: merge two base64 CRDT docs
function mergeDocs(doc1Base64, doc2Base64) {
  const doc1Bytes = Buffer.from(doc1Base64, 'base64');
  const doc2Bytes = Buffer.from(doc2Base64, 'base64');

  const doc1 = Automerge.load(doc1Bytes);
  const doc2 = Automerge.load(doc2Bytes);

  const merged = Automerge.merge(doc1, doc2);
  const mergedBytes = Automerge.save(merged);

  return Buffer.from(mergedBytes).toString('base64');
}

// Expose HTTP endpoint using Functions Framework
functions.http('mergeAutoDoc', async (req, res) => {
  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  const { doc1, doc2 } = req.body || {};

  if (!doc1 || !doc2) {
    return res.status(400).send('Missing doc1 or doc2 in request body');
  }

  try {
    const mergedBase64 = mergeDocs(doc1, doc2);
    return res.status(200).json({ doc: mergedBase64 });
  } catch (err) {
    console.error('Error merging docs:', err);
    return res.status(500).send('Internal Server Error');
  }
});
