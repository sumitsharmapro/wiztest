const http = require('http');
const fs = require('fs');

const port = 8080;

const server = http.createServer((req, res) => {
  // Route to verify the specific Wiz file
  if (req.url === '/wizexercise.txt') {
    fs.readFile('/wizexercise.txt', 'utf8', (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end("Error: wizexercise.txt not found at root.");
        return;
      }
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end(data);
    });
  } 
  // Default landing page
  else {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end('<h1>Wiz Technical Exercise</h1><p>The Secure Application Tier is officially <b>Online</b>.</p>');
  }
});

// Binding to 0.0.0.0 is mandatory for Cloud/Docker environments
server.listen(port, '0.0.0.0', () => {
  console.log(`Server running on port ${port}`);
});
