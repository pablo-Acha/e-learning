import { Router } from "express";
import { createModule, getModulesByClass, createClass, getClasses } from "../controllers/classes.controller.js";
import { verifyToken,authMiddleware, allowRoles } from "../middlewares/auth.middleware.js";

const router = Router();

// // Crear clase → solo teacher
router.post("/", authMiddleware, allowRoles("teacher"), createClass);

// // Listar clases → cualquier usuario logueado
router.get("/", authMiddleware, getClasses);

// Obtener módulos de una clase
router.get("/:id/modules", verifyToken, getModulesByClass);


// Crear módulo dentro de una clase
router.post("/:id/modules", verifyToken, createModule);

export default router;
