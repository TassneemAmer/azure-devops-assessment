const http = require('node:http');

function createServer() {
  return http.createServer((request, response) => {
    if (request.method === 'GET' && request.url === '/health') {
      response.writeHead(200, { 'content-type': 'application/json; charset=utf-8' });
      response.end(JSON.stringify({ status: 'ok' }));
      return;
    }

    if (request.method === 'GET' && request.url === '/') {
      response.writeHead(200, { 'content-type': 'application/json; charset=utf-8' });
      response.end(JSON.stringify({ message: 'Azure DevOps assessment API' }));
      return;
    }

    response.writeHead(404, { 'content-type': 'application/json; charset=utf-8' });
    response.end(JSON.stringify({ error: 'Not found' }));
  });
}

if (require.main === module) {
  const port = Number.parseInt(process.env.PORT || '3000', 10);
  const server = createServer();

  server.listen(port, '0.0.0.0', () => {
    console.log(`API listening on port ${port}`);
  });
}

module.exports = { createServer };
