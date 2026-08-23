# Stage 1: Build the Flutter web app
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy dependency files
COPY pubspec.* ./
RUN flutter pub get

# Copy source code and build
COPY . .
RUN flutter build web --wasm

# Stage 2: Serve the app using Nginx
FROM nginx:alpine

# Copy the built web app from the previous stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
