#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Closed synthetic RPC peer; no CLI reader, account access, network or Keychain.
import json
import os
from pathlib import Path
import sys
home = Path(os.environ['HOME'])
session = None
sent = False
def envelope(data):
    return {'sessionId': session, 'storeEpoch': 'u7-synthetic-epoch', 'consentGeneration': 1, 'data': data}
def reply(request, data):
    print(json.dumps({'jsonrpc': '2.0', 'id': request['id'], 'result': envelope(data)}), flush=True)
for line in sys.stdin:
    request = json.loads(line)
    method = request['method']
    if method == 'initialize':
        session = request['params']['sessionId']
        (home / 'capabilities.json').write_text(json.dumps(request['params']['capabilities']))
        reply(request, {'protocolVersion': '1.0', 'serverVersion': 'synthetic', 'capabilities': ['consent', 'credentials']})
    elif method == 'consent/get':
        reply(request, {'consentTextVersion': 1, 'scopes': [{
            'scope': 'claude.account_usage.saved_login', 'tool': 'claude', 'route': 'saved_login_api',
            'detected': True, 'retired': False, 'state': 'allowed', 'defaultCheck': False,
            'keychain': 'allow', 'cleanupPending': False}]})
        if not sent:
            sent = True
            print(json.dumps({'jsonrpc': '2.0', 'method': 'credentials/request', 'params': envelope({
                'operationId': 'u7-synthetic-operation', 'provider': 'claude',
                'scope': 'claude.account_usage.saved_login', 'interactive': False})}), flush=True)
    elif method == 'credentials/result':
        value = request['params']
        # Only public synthetic metadata is retained; never record a token value.
        (home / 'outcome.json').write_text(json.dumps({'operationId': value['operationId'],
            'outcome': value['outcome'], 'hasToken': 'accessToken' in value or 'expiresAt' in value}))
        reply(request, {})
    elif method == 'shutdown':
        if 'id' in request:
            reply(request, {})
        break
