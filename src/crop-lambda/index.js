const { S3Client, GetObjectCommand, PutObjectCommand } = require("@aws-sdk/client-s3");
const Jimp = require("jimp");

const s3 = new S3Client({ region: process.env.AWS_REGION });

exports.handler = async (event) => {
  const results = [];

  for (const record of event.Records) {
    try {
      const body = JSON.parse(record.body);
      const s3Event = body.Records[0];

      const sourceBucket = s3Event.s3.bucket.name;
      const sourceKey = decodeURIComponent(s3Event.s3.object.key.replace(/\+/g, " "));

      console.log(`Procesando imagen: ${sourceKey}`);

      const getCommand = new GetObjectCommand({
        Bucket: sourceBucket,
        Key: sourceKey,
      });

      const s3Response = await s3.send(getCommand);
      const imageBuffer = await streamToBuffer(s3Response.Body);

      const image = await Jimp.read(imageBuffer);
      image.resize(40, 40);

      const size = 40;
      const mask = new Jimp(size, size, 0x00000000);

      for (let x = 0; x < size; x++) {
        for (let y = 0; y < size; y++) {
          const dx = x - size / 2;
          const dy = y - size / 2;
          if (dx * dx + dy * dy <= (size / 2) * (size / 2)) {
            mask.setPixelColor(0xffffffff, x, y);
          }
        }
      }

      image.mask(mask, 0, 0);

      const processedBuffer = await image.getBufferAsync(Jimp.MIME_PNG);

      const filename = sourceKey.split("/").pop().split(".")[0];
      const destKey = `${process.env.PROCESSED_PREFIX}${filename}_circular.png`;

      await s3.send(
        new PutObjectCommand({
          Bucket: sourceBucket,
          Key: destKey,
          Body: processedBuffer,
          ContentType: "image/png",
        })
      );

      console.log(`Imagen procesada guardada en: ${destKey}`);
      results.push({ status: "ok", key: destKey });

    } catch (error) {
      console.error("Error procesando registro:", error);
      results.push({ status: "error", error: error.message });
      throw error;
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