const express = require('express');
const bodyParser = require('body-parser');
const forge = require('node-forge');
require('dotenv').config();

const app = express();
app.use(bodyParser.json());

const privateKeyPem = process.env.ROOT_PRIVATE_KEY;
const privateKey = forge.pki.privateKeyFromPem(privateKeyPem);

app.post('/sign-cert', (req, res) => {
  const certContent = JSON.stringify(req.body);
  const md = forge.md.sha256.create();
  md.update(certContent, 'utf8');
  const signature = privateKey.sign(md);
  const signatureBase64 = forge.util.encode64(signature);
  res.json({ rootSignature: signatureBase64 });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server on port ${PORT}`));
