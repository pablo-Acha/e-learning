import { prisma } from "../prisma.js"; // asegúrate de exportar prisma client desde src/prisma.js
import { uploadFile } from "../utils/s3.js";
import multer from "multer"

const upload = multer({ dest: "temp/" });

export const createClass = async (req, res) => {
  try {
    const { title, description } = req.body;
    const teacherId = req.user.id; // del auth middleware token jwt

    const newClass = await prisma.class.create({
      data: {
        title,
        description,
        teacherId
      }
    });

    

    res.json(newClass);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

export const getClasses = async (req, res) => {
  try {
    const classes = await prisma.class.findMany({
      include: { teacher: { select: { id: true, name: true, email: true } } }
    });
    res.json(classes);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Error obteniendo clases" });
  }
};

export const getModulesByClass = async (req, res) => {
  try {
    const { id } = req.params;
    const modules = await prisma.module.findMany({
      where: { classId: id },
      orderBy: { order: "asc" },
    });
    res.json({ modules });
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

