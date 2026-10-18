#!/usr/bin/env python3
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_POST(self):
        payload = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        evidence = Path('/tmp/raycompanion-provider-evidence.jsonl')
        with evidence.open('a') as output:
            output.write(json.dumps({'path': self.path, 'model': payload.get('model'), 'messages': payload.get('messages'), 'stream': payload.get('stream')}) + '\n')
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.send_header('Cache-Control', 'no-cache')
        self.end_headers()
        calculator = any('Use the calculator.' in str(message.get('content', '')) for message in payload['messages'])
        tool_results = [message for message in payload['messages'] if message.get('role') == 'tool']
        extension = any('Use the Base64 extension.' in str(message.get('content', '')) for message in payload['messages'])
        if extension and not tool_results:
            name = next(tool['function']['name'] for tool in payload.get('tools', []) if tool['function']['name'].endswith('base64-encode'))
            event = {'choices': [{'delta': {'tool_calls': [{'index': 0, 'id': 'extension-proof', 'type': 'function', 'function': {'name': name, 'arguments': '{"input":"hello"}'}}]}}]}
            self.wfile.write(('data: ' + json.dumps(event) + '\r\n\r\n').encode())
            self.wfile.write(b'data: [DONE]\r\n\r\n'); self.wfile.flush()
            return
        if calculator and not tool_results:
            event = {'choices': [{'delta': {'tool_calls': [{'index': 0, 'id': 'calculator-proof', 'type': 'function', 'function': {'name': 'raycompanion__calculate', 'arguments': '{"expression":"2 * (3 + 4)"}'}}]}}]}
            self.wfile.write(('data: ' + json.dumps(event) + '\r\n\r\n').encode())
            self.wfile.write(b'data: [DONE]\r\n\r\n'); self.wfile.flush()
            return
        reply = '## Stream verified\n\nThis reply came through the **OpenAI-compatible HTTP client**, from a local test server.\n\n| Check | Result |\n| --- | --- |\n| Exact prompt | Received |\n| Follow-up history | ' + str(len(payload['messages'])) + ' messages |\n\n```swift\nlet seamless = true\n```\n\nUnicode survived: 🦊.\n'
        if calculator:
            reply = 'The calculator returned **' + str(tool_results[-1].get('content')) + '**.'
        if extension:
            reply = 'The installed Base64 extension returned **' + str(tool_results[-1].get('content')) + '**.'
        try:
            self.wfile.write(b': keepalive\r\n\r\n'); self.wfile.flush()
            for start in range(0, len(reply), 9):
                data = json.dumps({'choices': [{'delta': {'content': reply[start:start+9]}}]}, ensure_ascii=False)
                self.wfile.write(('data: ' + data + '\r\n\r\n').encode()); self.wfile.flush()
                time.sleep(0.055)
            self.wfile.write(b'data: [DONE]\r\n\r\n'); self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError): pass

print('Test provider listening on 127.0.0.1:18764', flush=True)
ThreadingHTTPServer(('127.0.0.1', 18764), Handler).serve_forever()
