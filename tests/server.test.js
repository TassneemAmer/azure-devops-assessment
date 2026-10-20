const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');
const { createServer } = require('../app/server');

let server;
let baseUrl;
const items = [];
let nextItemId = 1;

const databasePool = {
  async query(query, values = []) {
    if (query.includes('CREATE TABLE IF NOT EXISTS assessment_items')) {
      return { rows: [] };
    }
    if (query === 'SELECT 1') {
      return { rows: [{ '?column?': 1 }] };
    }
    if (query.includes('INSERT INTO assessment_items')) {
      const item = {
        id: String(nextItemId++),
        name: values[0],
        created_at: new Date().toISOString(),
      };
      items.push(item);
      return { rows: [item] };
    }
    if (query.includes('FROM assessment_items')) {
      return { rows: [...items].reverse() };
    }
    throw new Error(`Unexpected SQL query: ${query}`);
  },
  async end() {},
};

before(async () => {
  server = createServer({ databasePool });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  baseUrl = `http://127.0.0.1:${address.port}`;
});

after(async () => {
  await new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
  await databasePool.end();
});

test('GET /health reports that the API is healthy', async () => {
  const response = await fetch(`${baseUrl}/health`);

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: 'ok' });
});

test('unknown routes return 404', async () => {
  const response = await fetch(`${baseUrl}/missing`);

  assert.equal(response.status, 404);
  assert.deepEqual(await response.json(), { error: 'Not found' });
});

test('GET /ready confirms the database is reachable', async () => {
  const response = await fetch(`${baseUrl}/ready`);

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: 'ready', database: 'ok' });
});

test('POST /items saves an item and GET /items lists it', async () => {
  const createResponse = await fetch(`${baseUrl}/items`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ name: 'assessment demo' }),
  });

  assert.equal(createResponse.status, 201);
  const created = await createResponse.json();
  assert.equal(created.item.id, '1');
  assert.equal(created.item.name, 'assessment demo');

  const listResponse = await fetch(`${baseUrl}/items`);
  assert.equal(listResponse.status, 200);
  assert.deepEqual((await listResponse.json()).items.map(({ id, name }) => ({ id, name })), [
    { id: '1', name: 'assessment demo' },
  ]);
});

test('POST /items rejects an empty name', async () => {
  const response = await fetch(`${baseUrl}/items`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ name: '   ' }),
  });

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    error: 'name must be a non-empty string of at most 120 characters',
  });
});
