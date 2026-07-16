FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src ./src
RUN mvn -B -q package

FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S delivery && adduser -S delivery -G delivery
WORKDIR /app
COPY --from=build /workspace/target/delivery-platform-0.1.0.jar app.jar
USER delivery
EXPOSE 8080
ENTRYPOINT ["java","-XX:MaxRAMPercentage=75.0","-jar","/app/app.jar"]
