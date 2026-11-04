# Image del backend Spring Boot (multi-etapa):
# 1) build con Maven/Temurin 21 (compila y empaqueta el jar)
# 2) runtime con JRE 21 alpine (imago liviana, solo el jar)
# El jar en la imagen NO lleva credenciales: las variables de entorno
# (DB_*, DEEPGRAM_API_KEY, CORS_ORIGINS) se inyectan en runtime
# (docker run --env-file o Azure Container Apps -> Environment variables).

# ---------- Etapa de build ----------
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
# Copia primero el pom para aprovechar la cache de dependencias:
# si pom.xml no cambia, la descarga de dependencias se reutiliza entre builds.
COPY pom.xml .
RUN mvn -q -B dependency:go-offline -DskipTests
COPY src ./src
RUN mvn -q -B -DskipTests package

# ---------- Etapa de runtime ----------
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=build /app/target/portal-tramites-backend-0.1.0.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
