const express = require("express");
const crypto = require("crypto");
const bodyParser = require("body-parser");
require("dotenv").config();

const app = express();
app.use(bodyParser.json());

// ✅ LOAD ROOT PRIVATE KEY FROM RENDER SECRET FILE
const PRIVATE_KEY_PATH = "/etc/secrets/ROOT_PRIVATE_KEY";

if (!fs.existsSync(PRIVATE_KEY_PATH)) {
  console.error("❌ ROOT_PRIVATE_KEY secret file NOT FOUND!");
  process.exit(1);
}

const ROOT_PRIVATE_KEY = fs.readFileSync(PRIVATE_KEY_PATH, "utf8");

// ✅ TEST KEY LOAD ON BOOT
try {
  crypto.createPrivateKey(ROOT_PRIVATE_KEY);
  console.log("✅ Root private key loaded successfully");
} catch (e) {
  console.error("❌ Invalid private key format:", e.message);
  process.exit(1);
}

// ✅ SIGN USER CERT DATA
app.post("/sign-cert", (req, res) => {
  try {
    const { certDataToSign } = req.body;

    if (!certDataToSign) {
      return res.status(400).json({ error: "Missing certDataToSign" });
    }

    // ✅ CREATE SIGNATURE (SHA256 + RSA PKCS1 v1.5)
    const signer = crypto.createSign("RSA-SHA256");
    signer.update(certDataToSign);
    signer.end();

    const signatureBase64 = signer.sign(ROOT_PRIVATE_KEY, "base64");

    return res.json({
      signature: signatureBase64,
      algorithm: "SHA256withRSA",
    });

  } catch (err) {
    console.error("❌ Error in /sign-cert:", err);
    return res.status(500).json({ error: err.message });
  }
});

// ✅ VERIFY CERT SIGNATURE (OPTIONAL SERVER TEST)
app.post("/verify-cert", (req, res) => {
  try {
    const { certData, signatureBase64, publicKeyPem } = req.body;

    const verifier = crypto.createVerify("RSA-SHA256");
    verifier.update(certData);
    verifier.end();

    const isValid = verifier.verify(publicKeyPem, signatureBase64, "base64");

    return res.json({ valid: isValid });

  } catch (err) {
    console.error("❌ Error in /verify-cert:", err);
    return res.status(500).json({ error: err.message });
  }
});

// ✅ HEALTH CHECK
app.get("/", (req, res) => {
  res.send("✅ Nodity Root CA Server Running");
});

// ✅ START SERVER
const PORT = process.env.PORT || 3000;
app.listen(3000, () => {
  console.log("Server running on port 3000");
});

