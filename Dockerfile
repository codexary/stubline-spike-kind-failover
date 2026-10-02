FROM eclipse-temurin:21.0.12.1_1-jdk-noble AS build
WORKDIR /src
COPY .mvn .mvn
COPY mvnw pom.xml ./
RUN --mount=type=cache,target=/root/.m2 ./mvnw -q -DskipTests org.apache.maven.plugins:maven-dependency-plugin:3.11.0:go-offline
COPY src src
RUN --mount=type=cache,target=/root/.m2 ./mvnw -q -DskipTests package
FROM eclipse-temurin:21.0.12.1_1-jre-noble
RUN useradd --system --uid 10001 app
WORKDIR /app
COPY --from=build /src/target/*.jar app.jar
USER 10001
EXPOSE 8080
ENTRYPOINT ["java", "-cp", "app.jar", "com.elsworne.stubline.spike.kindfailover.PodServer"]
