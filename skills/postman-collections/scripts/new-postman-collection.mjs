#!/usr/bin/env node

import fs from 'fs';
import path from 'path';

function getArg(flag) {
  for (let index = 0; index < process.argv.length; index += 1) {
    const token = process.argv[index];
    if (token === flag) return process.argv[index + 1] ?? '';
    if (token.startsWith(flag + '=')) return token.slice(flag.length + 1);
  }
  return '';
}

const name = getArg('--name');
const output = getArg('--output');
const requestsFile = getArg('--requests');
const baseUrl = getArg('--base-url') || 'http://localhost:8080';
const rootPath = getArg('--root-path') || '';

if (!name || !output || !requestsFile) {
  console.error('Usage: node new-postman-collection.mjs --name <name> --output <collection.json> --requests <request-catalog.json> [--base-url <url>] [--root-path </prefix>]');
  process.exit(1);
}

const catalog = JSON.parse(fs.readFileSync(requestsFile, 'utf8'));

function normalizePath(requestPath) {
  const combined = `${rootPath}${requestPath}`.replace(/\/+/g, '/');
  return combined.startsWith('/') ? combined : `/${combined}`;
}

function buildHeaders(headers = {}) {
  return Object.entries(headers).map(([key, value]) => ({ key, value, type: 'text' }));
}

function buildQuery(query = {}) {
  return Object.entries(query).map(([key, value]) => ({ key, value: String(value) }));
}

function buildTests(expectedStatus) {
  const testLines = [
    `pm.test("status is ${expectedStatus}", function () {`,
    `  pm.response.to.have.status(${expectedStatus});`,
    '});',
    'pm.test("response time is under 5s", function () {',
    '  pm.expect(pm.response.responseTime).to.be.below(5000);',
    '});'
  ];

  return [{
    listen: 'test',
    script: {
      type: 'text/javascript',
      exec: testLines
    }
  }];
}

function buildRequestItem(request) {
  const item = {
    name: request.name,
    request: {
      method: request.method,
      header: buildHeaders(request.headers),
      url: {
        raw: `{{baseUrl}}${normalizePath(request.path)}`,
        host: ['{{baseUrl}}'],
        path: normalizePath(request.path).split('/').filter(Boolean),
        query: buildQuery(request.query)
      },
      description: request.description || ''
    },
    event: buildTests(request.expectedStatus || 200)
  };

  if (request.body) {
    item.request.body = {
      mode: 'raw',
      raw: JSON.stringify(request.body, null, 2),
      options: {
        raw: {
          language: 'json'
        }
      }
    };
  }

  return item;
}

const collection = {
  info: {
    name,
    schema: 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
    description: `Generated from request catalog ${path.basename(requestsFile)}.`
  },
  variable: [
    { key: 'baseUrl', value: baseUrl },
    { key: 'authToken', value: 'SET_ME' },
    { key: 'transactionId', value: 'tx-local' },
    { key: 'smokeMode', value: 'true' }
  ],
  item: (catalog.folders || []).map(folder => ({
    name: folder.name,
    item: (folder.requests || []).map(buildRequestItem)
  }))
};

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, JSON.stringify(collection, null, 2) + '\n', 'utf8');
console.log(`Generated ${output}`);