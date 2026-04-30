# Use official Node image
FROM node:18-alpine

# Create app directory
WORKDIR /app

# Copy package files first (for caching)
COPY package*.json ./

# Install dependencies
RUN npm install --omit=dev

# Copy rest of the code
COPY . .

# Expose port (change if your app uses different port)
EXPOSE 3000

# Start the app
CMD ["npm", "start"]
