const functions = require('@google-cloud/functions-framework');
const Automerge = require('@automerge/automerge');

// Cloud Function: explodeAutoDoc (LOCAL)
functions.http('explodeAutoDoc', async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  // The doc is expected as a base64-encoded string
  if (!req.body || typeof req.body.doc !== 'string') {
    return res.status(400).send('Missing doc (base64) in request body');
  }

  try {
    // Convert the base64 doc -> bytes
    const docBytes = Buffer.from(req.body.doc, 'base64');

    // Load into Automerge
    const doc = Automerge.load(docBytes);

    // Convert to plain JSON
    const jsonData = Automerge.toJS(doc);

	// Return a single flat object that includes every exploded field 
	// plus the original base64 doc string under the key "doc"
	res.status(200).json({
	  ...jsonData,
	  doc: req.body.doc
	});
  } catch (err) {
    console.error('Error exploding doc:', err);
    res.status(500).send('Internal Server Error');
  }
});
