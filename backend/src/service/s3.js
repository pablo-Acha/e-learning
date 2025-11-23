import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";

export const s3 = new S3Client({
  region: process.env.AWS_REGION,
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
  }
});

export const uploadVideoToS3 = async (fileBuffer, classId, moduleId, fileName, mimeType) => {
  const bucket = process.env.S3_BUCKET_NAME;

  const key = `${classId}/${moduleId}/${fileName}`;

  const params = {
    Bucket: bucket,
    Key: key,
    Body: fileBuffer,
    ContentType: mimeType
  };

  
  await s3.send(new PutObjectCommand(params));

  return `https://${bucket}.s3.${process.env.AWS_REGION}.amazonaws.com/${key}`;
}
