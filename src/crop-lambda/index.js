const { S3Client, GetObjectCommand, PutObjectCommand } = require("@aws-sdk/client-s3");
const sharp = require("sharp");

const s3 = new S3Client({ region: process.env.AWS_REGION });

exports.handler = async (event) => {
  const results = [];

  for (const record of event.Records) {
    try {
      // Parsear mensaje SQS
      const body = JSON.parse(record.body);
      const s3Event = body.Records[0];

      const sourceBucket = s3Event.s3.bucket.name;
      const sourceKey = decodeURIComponent(s3Event.s3.object.key.replace(/\+/g, " "));

      console.log(`Procesando imagen: ${sourceKey}`);

      // Descargar imagen original desde S3
      const getCommand = new GetObjectCommand({
        Bucket: sourceBucket,
        Key: sourceKey,
      });

      const s3Response = await s3.send(getCommand);
      const imageBuffer = await streamToBuffer(s3Response.Body);

      // Crear máscara circular SVG
      const circleMask = Buffer.from(
        `<svg width="40" height="40">
          <circle cx="20" cy="20" r="20" fill="white"/>
        </svg>`
      );

      // Procesar imagen: 40x40, recorte circular, PNG con transparencia
      const processedImage = await sharp(imageBuffer)
        .resize(40, 40, { fit: "cover", position: "center" })
        .composite([{ input: circleMask, blend: "dest-in" }])
        .png()
        .toBuffer();

      // Generar key de destino en processed/
      const filename = sourceKey.split("/").pop().split(".")[0];
      const destKey = `${process.env.PROCESSED_PREFIX}${filename}_circular.png`;

      // Subir imagen procesada a S3
      await s3.send(
        new PutObjectCommand({
          Bucket: sourceBucket,
          Key: destKey,
          Body: processedImage,
          ContentType: "image/png",
        })
      );

      console.log(`Imagen procesada guardada en: ${destKey}`);
      results.push({ status: "ok", key: destKey });

    } catch (error) {
      console.error("Error procesando registro:", error);
      results.push({ status: "error", error: error.message });
      throw error; // Permite que SQS reintente
    }
  }

  return { results };
};

function streamToBuffer(stream) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    stream.on("data", (chunk) => chunks.push(chunk));
    stream.on("end", () => resolve(Buffer.concat(chunks)));
    stream.on("error", reject);
  });
}