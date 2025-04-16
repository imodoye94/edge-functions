# Use the official Node.js 18 image
FROM node:18

# Set working directory
WORKDIR /usr/src/app

# Install only production dependencies
COPY package*.json ./
RUN npm install --production

# Copy the actual code
COPY . .

# Expose the internal port used by Functions Framework
EXPOSE 8080

# Start the function
CMD ["npm", "start"]
