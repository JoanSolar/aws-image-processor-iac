const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const busboy = require("busboy");
const { v4: uuidv4 } = require("uuid");

const s3 = new S3Client({ region: process.env.AWS_REGION });

const ALLOWED_TYPES = ["image/jpeg", "image/png", "image/gif", "image/webp"];
const MAX_SIZE = 10 * 1024 * 1024; // 10 MB

exports.handler = async (event) => {
  try {
    const contentType =
      event.headers["content-type"] || event.headers["Content-Type"];

    if (!contentType) {
      return response(400, { error: "Content-Type requerido" });
    }

    let fileBuffer;
    let fileMimeType;
    let fileExtension;

    // Multipart/form-data
    if (contentType.includes("multipart/form-data")) {
      const result = await parseMultipart(event, contentType);
      fileBuffer = result.buffer;
      fileMimeType = result.mimeType;
      fileExtension = result.extension;
    }
    // JSON + base64
    else if (contentType.includes("application/json")) {
      const body = JSON.parse(event.body);
      if (!body.image || !body.mimeType) {
        return response(400, { error: "Campos image y mimeType requeridos" });
      }
      fileBuffer = Buffer.from(body.image, "base64");
      fileMimeType = body.mimeType;
      fileExtension = getExtension(fileMimeType);
    } else {
      return response(400, { error: "Content-Type no soportado" });
    }

    // Validar tipo
    if (!ALLOWED_TYPES.includes(fileMimeType)) {
      return response(400, { error: "Tipo de archivo no permitido. Usar: jpg, png, gif, webp" });
    }

    // Validar tamaño
    if (fileBuffer.length > MAX_SIZE) {
      return response(400, { error: "Archivo supera el límite de 10 MB" });
    }

    const key = `${process.env.UPLOAD_PREFIX}${uuidv4()}.${fileExtension}`;

    await s3.send(
      new PutObjectCommand({
        Bucket: process.env.S3_BUCKET,
        Key: key,
        Body: fileBuffer,
        ContentType: fileMimeType,
      })
    );

    return response(200, {
      message: "Imagen subida correctamente",
      key: key,
    });
  } catch (error) {
    console.error("Error:", error);
    return response(500, { error: "Error interno del servidor" });
  }
};

function parseMultipart(event, contentType) {
  return new Promise((resolve, reject) => {
    const bb = busboy({ headers: { "content-type": contentType } });
    let fileBuffer;
    let mimeType;
    let extension;

    bb.on("file", (name, file, info) => {
      mimeType = info.mimeType;
      extension = getExtension(mimeType);
      const chunks = [];

      file.on("data", (chunk) => chunks.push(chunk));
      file.on("end", () => {
        fileBuffer = Buffer.concat(chunks);
      });
    });

    bb.on("finish", () => resolve({ buffer: fileBuffer, mimeType, extension }));
    bb.on("error", reject);

    const body = event.isBase64Encoded
      ? Buffer.from(event.body, "base64")
      : Buffer.from(event.body);

    bb.write(body);
    bb.end();
  });
}

function getExtension(mimeType) {
  const map = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/gif": "gif",
    "image/webp": "webp",
  };
  return map[mimeType] || "jpg";
}

function response(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  };
}