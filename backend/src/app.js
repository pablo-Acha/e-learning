import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { connectDB } from "./config/db.js";
import authRoutes from "./routes/auth.routes.js";
import classesRoutes from "./routes/classes.routes.js";
import moduleRoutes from "./routes/module.routes.js";
import videoRoutes from "./routes/video.routes.js";
import uploadRoutes from "./routes/upload.routes.js";
import teacherRoutes from "./routes/teacher.routes.js";
import studentRoutes from "./routes/student.routes.js"
import enrollmentRoutes from "./routes/enrollment.routes.js"
import adminRoutes from "./routes/admin.routes.js"
dotenv.config();


const app = express();


app.use(cors());
app.use(express.json());


app.use(express.urlencoded({ extended: true }));
// Rutas de autenticación
app.use("/auth", authRoutes);

// Rutas de clases
app.use("/classes", classesRoutes);

// Rutas de módulos
app.use("/modules", moduleRoutes);

// Rutas de videos
app.use("/videos", videoRoutes);
app.get("/test-error", (req, res) => {
  throw new Error("Error de prueba para Discord");
});

// Rutas de upload
app.use("/upload", uploadRoutes);
app.use("/teacher", teacherRoutes);
app.use("/students", studentRoutes);
app.use("/enrollments", enrollmentRoutes);
app.use("/admin", adminRoutes);

app.get("/", (req, res) => {
  res.json({ msg: "E-Study Backend OK!" });
});
// app.get("/test-db", async (req, res) => {
//   try {
//     const result = await prisma.$queryRaw`SELECT NOW()`;
//     res.json({ now: result });
//   } catch (err) {
//     console.error(err);
//     res.status(500).json({ error: "Error conectando a DB" });
//   }
// });

// inicializar DB
connectDB();

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Backend E-Study iniciado en puerto ${PORT}`));
