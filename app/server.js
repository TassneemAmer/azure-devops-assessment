const http = require('node:http');
const { Pool } = require('pg');

function createDatabasePool() {
  if (!process.env.PGHOST) return null;

  return new Pool({
    host: process.env.PGHOST,
    port: Number.parseInt(process.env.PGPORT || '5432', 10),
    database: process.env.PGDATABASE,
    user: process.env.PGUSER,
    password: process.env.PGPASSWORD,
    ssl: { rejectUnauthorized: true },
    connectionTimeoutMillis: 5000,
  });
}

function sendJson(response, statusCode, body) {
  response.writeHead(statusCode, { 'content-type': 'application/json; charset=utf-8' });
  response.end(JSON.stringify(body));
}

async function readJsonBody(request) {
  let body = '';

  for await (const chunk of request) {
    body += chunk;
    if (Buffer.byteLength(body) > 8192) {
      const error = new Error('Request body is too large');
      error.statusCode = 413;
      throw error;
    }
  }

  try {
    return JSON.parse(body);
  } catch {
    const error = new Error('Request body must be valid JSON');
    error.statusCode = 400;
    throw error;
  }
}

function createServer({ databasePool = createDatabasePool() } = {}) {
  const server = http.createServer(async (request, response) => {
    if (request.method === 'GET' && request.url === '/health') {
      sendJson(response, 200, { status: 'ok' });
      return;
    }

    if (request.method === 'GET' && request.url === '/ready') {
      if (!databasePool) {
        sendJson(response, 503, { status: 'not_ready', database: 'not_configured' });
        return;
      }

      try {
        await databasePool.query('SELECT 1');
        sendJson(response, 200, { status: 'ready', database: 'ok' });
      } catch {
        sendJson(response, 503, { status: 'not_ready', database: 'unavailable' });
      }
      return;
    }

    if (request.url === '/items' && (request.method === 'GET' || request.method === 'POST')) {
      if (!databasePool) {
        sendJson(response, 503, { error: 'Database is not configured' });
        return;
      }

      try {
        if (request.method === 'GET') {
          const result = await databasePool.query(
            'SELECT id::text AS id, name, created_at FROM assessment_items ORDER BY created_at DESC, id DESC',
          );
          sendJson(response, 200, { items: result.rows });
          return;
        }

        let body;
        try {
          body = await readJsonBody(request);
        } catch (error) {
          sendJson(response, error.statusCode || 400, { error: error.message });
          return;
        }

        const name = typeof body?.name === 'string' ? body.name.trim() : '';
        if (!name || name.length > 120) {
          sendJson(response, 400, { error: 'name must be a non-empty string of at most 120 characters' });
          return;
        }

        const result = await databasePool.query(
          'INSERT INTO assessment_items (name) VALUES ($1) RETURNING id::text AS id, name, created_at',
          [name],
        );
        sendJson(response, 201, { item: result.rows[0] });
      } catch {
        sendJson(response, 503, { error: 'Database is unavailable' });
      }
      return;
    }

    if (request.method === 'GET' && request.url === '/') {
      sendJson(response, 200, { message: 'Azure DevOps assessment API' });
      return;
    }

    sendJson(response, 404, { error: 'Not found' });
  });
  server.databasePool = databasePool;
  return server;
}

if (require.main === module) {
  const port = Number.parseInt(process.env.PORT || '3000', 10);
  const server = createServer();

  server.listen(port, '0.0.0.0', () => {
    console.log(`API listening on port ${port}`);
  });

  const close = () => {
    server.close(async () => {
      await server.databasePool?.end();
      process.exit(0);
    });
  };
  process.once('SIGTERM', close);
  process.once('SIGINT', close);
}

module.exports = { createDatabasePool, createServer };
