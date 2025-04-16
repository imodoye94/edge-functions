const functions = require('@google-cloud/functions-framework');
const Automerge = require('@automerge/automerge');

// Helper to merge a JSON object into an existing doc
function mergeAutodoc(oldDocBytes, newJson) {
  const oldDoc = oldDocBytes ? Automerge.load(oldDocBytes) : Automerge.init();
  const updatedDoc = Automerge.change(oldDoc, doc => {
    for (const key in newJson) {
      doc[key] = newJson[key];
    }
  });
  return Automerge.save(updatedDoc); // returns a Uint8Array
}

// Expose HTTP endpoint: /generateAutoDoc
functions.http('generateAutoDoc', async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  if (!req.body || typeof req.body !== 'object' || !('json_data' in req.body)) {
    return res.status(400).send('Missing json_data in request body');
  }

  try {
    const jsonData = req.body.json_data;
    const oldDocBytes = req.body.old_doc ? Buffer.from(req.body.old_doc, 'base64') : null;

    const newDocBytes = mergeAutodoc(oldDocBytes, jsonData);
    const newDocBase64 = Buffer.from(newDocBytes).toString('base64');

    res.status(200).json({ doc: newDocBase64 });
  } catch (error) {
    console.error('Automerge error:', error);
    res.status(500).send('Internal Server Error');
  }
});
