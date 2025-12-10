import express from "express";
import { authMiddleware,verifyToken } from "../middlewares/auth.middleware.js";
import { getModulesByClass } from "../controllers/classes.controller.js";
import { createModule , uploadVideo, getModuleVideo, uploadVideoMiddleware,   deleteModule, updateModule} from "../controllers/module.controller.js";
const router = express.Router();

// Genera signed URL para reproducir video
router.get("/:id/video", verifyToken, getModuleVideo);

router.post("/:id/video", verifyToken, uploadVideoMiddleware, uploadVideo);

router.delete("/:id", verifyToken, deleteModule);
router.put("/:id", verifyToken, updateModule);

export default router;
