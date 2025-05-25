FROM node:18

# Create app directory
WORKDIR /app

# Install dependencies
COPY package.json ./
RUN npm install

# Copy app code
COPY . .

# Expose port
EXPOSE 3000

# Run the app
CMD ["node", "index.js"]
