// src/controllers/module.controller.js
import multer from "multer";
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
// import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { prisma } from "../prisma.js";
import {s3, getSignedUrl} from "../config/s3.js";
import { DeleteObjectCommand } from "@aws-sdk/client-s3";

export const getVideoSignedUrl = async (req, res) => {
  try {
    const { moduleId } = req.params;

    // Obtener módulo y la clase asociada
    const module = await prisma.module.findUnique({
      where: { id: moduleId },
      include: { class: true },
    });

    if (!module) return res.status(404).json({ msg: "Módulo no encontrado" });

    // Verificar que el usuario está inscrito si es estudiante
    if (req.user.role === "student") {
      const enrolled = await prisma.enrollment.findUnique({
        where: {
          studentId_classId: { studentId: req.user.id, classId: module.classId },
        },
      });
      if (!enrolled) return res.status(403).json({ msg: "No estás inscrito" });
    }

    // Generar URL firmada
    const command = new GetObjectCommand({
      Bucket: process.env.AWS_BUCKET_NAME, // <-- variable de entorno correcta
      Key: module.videoUrl,                 // <-- debe ser solo la key
    });

    const url = await getSignedUrl(s3, command, { expiresIn: 3600 }); // 1 hora
    res.json({ url });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const createModule = async (req, res) => {
  try {
    const { title, description, order } = req.body; // incluimos description
    const classId = req.params.id;

    // Validación: solo teacher que creó la clase puede agregar módulos
    const classData = await prisma.class.findUnique({ where: { id: classId } });
    if (!classData) return res.status(404).json({ msg: "Clase no existe" });
    if (classData.teacherId !== req.user.id) {
      return res.status(403).json({ msg: "No autorizado" });
    }

    // Crear módulo
    const moduleData = await prisma.module.create({
      data: {
        title,
        description, // opcional
        classId,
        order
      }
    });

    res.json(moduleData);

  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};


export const getModulesByClass = async (req, res) => {
  const { id } = req.params;
  const modules = await prisma.module.findMany({
    where: { classId: id },
    orderBy: { order: "asc" },
  });
  res.json({ modules });
};

// const upload = multer({ storage: multer.memoryStorage() }); // memoria temporal

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 500 * 1024 * 1024 }
});
export const uploadVideoMiddleware = upload.single("video"); // campo "video" en form-data

export const uploadVideo = async (req, res) => {
  try {
    const moduleId = req.params.id;
    const file = req.file;

    if (!file) return res.status(400).json({ msg: "No se envió archivo" });

    // Buscar módulo
    const moduleData = await prisma.module.findUnique({ where: { id: moduleId } });
    if (!moduleData) return res.status(404).json({ msg: "Módulo no existe" });

    // Crear la key dentro del bucket
    const key = `modules/${moduleId}/${file.originalname}`;

    // Subir a S3
    const params = {
      Bucket: process.env.AWS_BUCKET_NAME,
      Key: key,             // <-- solo la key
      Body: file.buffer,
      ContentType: file.mimetype
    };

    await s3.send(new PutObjectCommand(params));

    // Guardar solo la key en la DB
    const updatedModule = await prisma.module.update({
      where: { id: moduleId },
      data: { videoUrl: key } // <-- solo la key
    });

    res.json({ msg: "Video subido correctamente", videoKey: updatedModule.videoUrl });

  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};



export const getModuleVideo = async (req, res) => {
  try {
    const moduleId = req.params.id;

    // Buscar módulo y obtener videoUrl
    const moduleData = await prisma.module.findUnique({
      where: { id: moduleId }
    });

    if (!moduleData) return res.status(404).json({ msg: "Módulo no existe" });
    if (!moduleData.videoUrl) return res.status(404).json({ msg: "Módulo no tiene video" });

    // Extraer la key dentro del bucket del videoUrl guardado
    const bucketUrl = `https://${process.env.AWS_BUCKET_NAME}.s3.${process.env.AWS_REGION}.amazonaws.com/`;
    const key = moduleData.videoUrl.replace(bucketUrl, "");

    // const signedUrl = getSignedUrl(key);
    const signedUrl = getSignedUrl(moduleData.videoUrl); // moduleData.videoUrl = key

    res.json({ signedUrl });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

export const updateModule = async (req, res) => {
  try {
    const moduleId = req.params.id;
    const { title, description } = req.body;

    const moduleData = await prisma.module.findUnique({
      where: { id: moduleId },
      include: { class: true },
    });
    if (!moduleData) return res.status(404).json({ msg: "Módulo no existe" });
    if (moduleData.class.teacherId !== req.user.id)
      return res.status(403).json({ msg: "No autorizado" });

    const updatedModule = await prisma.module.update({
      where: { id: moduleId },
      data: { title, description },
    });

    res.json(updatedModule);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Eliminar módulo
export const deleteModule = async (req, res) => {
  try {
    const moduleId = req.params.id;

    const moduleData = await prisma.module.findUnique({
      where: { id: moduleId },
      include: { class: true },
    });
    if (!moduleData) return res.status(404).json({ msg: "Módulo no existe" });
    if (moduleData.class.teacherId !== req.user.id)
      return res.status(403).json({ msg: "No autorizado" });

    // Eliminar video de S3 si existe
    if (moduleData.videoUrl) {
      await s3.send(
        new DeleteObjectCommand({
          Bucket: process.env.AWS_BUCKET_NAME,
          Key: moduleData.videoUrl,
        })
      );
    }

    await prisma.module.delete({ where: { id: moduleId } });

    res.json({ msg: "Módulo eliminado correctamente" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};