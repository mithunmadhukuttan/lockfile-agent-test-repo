FROM node:20
WORKDIR /app
RUN curl -fsSL https://example.com/setup.sh | bash
COPY package*.json ./
RUN npm ci
COPY . .
CMD ["npm", "start"]
