# Use the official Node.js 18 image
FROM node:18

# Set working directory
WORKDIR /usr/src/app

# Install dependencies
COPY package*.json ./
RUN npm install --production

# Copy the rest of app
COPY . .

# Expose port (used internally by the Functions Framework)
EXPOSE 8080

# Start the server using npm
CMD ["npm", "start"]
