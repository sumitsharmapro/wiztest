# 1. Use a slim, secure base image
FROM node:18-alpine

# 2. Set the working directory
WORKDIR /usr/src/app

# 3. Copy the required Wiz file into the image (as per requirements)
COPY wizexercise.txt /wizexercise.txt

# 4. Copy your application code (placeholder for now)
COPY . .

# 5. Expose the port your app runs on
EXPOSE 8080

# 6. Start the application
CMD [ "node", "index.js" ]
