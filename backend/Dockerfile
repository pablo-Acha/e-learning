FROM node:20-alpine

WORKDIR /app

# Copiar solo los package.json
COPY package*.json ./

# Instalar dependencias
RUN npm install --production

# Copiar el resto del código
COPY . .

# GENERAR PRISMA CLIENT usando una DATABASE_URL temporal
ENV DATABASE_URL="postgresql://user:pass@localhost:5432/db"

RUN npx prisma generate

EXPOSE 3000

CMD ["npm", "start"]
