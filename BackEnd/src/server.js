import { createServer } from 'node:http';

import { Server } from 'socket.io';

import app from './app.js';
import { env } from './config/env.js';
import { pool } from './config/database.js';
import { attachChatSocket } from './socket/chat.socket.js';

const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: env.corsOrigins.includes('*') ? true : env.corsOrigins,
    methods: ['GET', 'POST'],
  },
});
attachChatSocket(io);

try {
  await pool.query('SELECT 1');
  httpServer.listen(env.port, () => {
    console.log(`API running at http://localhost:${env.port}`);
    console.log(`Socket.IO chat ready at ws://localhost:${env.port}`);
  });
} catch (error) {
  console.error('Cannot connect to MySQL. Check that MySQL is running and .env is configured.');
  console.error(error.message);
  process.exitCode = 1;
  await pool.end();
}
