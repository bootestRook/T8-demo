#!/usr/bin/env python3

import argparse
import base64
import binascii
import copy
import getpass
import hashlib
import json
import mimetypes
import os
import re
import shutil
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid


DEFAULT_BASE_URL = 'http://ai-studio.dodjoy.com:3001'
DEFAULT_API_KEY = os.environ.get('MEDIA_API_KEY')
DEFAULT_PROVIDERS_PATH = (
    os.environ.get('MEDIA_API_PROVIDERS_PATH') or '/api/media/providers'
)
DEFAULT_GENERATE_PATH = (
    os.environ.get('MEDIA_API_GENERATE_PATH') or '/api/media/generate'
)
DEFAULT_TASK_PATH_TEMPLATE = (
    os.environ.get('MEDIA_API_TASK_PATH_TEMPLATE')
    or '/api/media/task/{taskId}'
)
DEFAULT_OPENAPI_PATH = (
    os.environ.get('MEDIA_API_OPENAPI_PATH') or '/api/media/openapi.json'
)
DEFAULT_UPLOAD_PATH = (
    os.environ.get('MEDIA_API_UPLOAD_PATH') or '/files/upload'
)
DEFAULT_AUTH_HEADER = os.environ.get('MEDIA_API_AUTH_HEADER') or 'Authorization'
DEFAULT_AUTH_PREFIX = os.environ.get('MEDIA_API_AUTH_PREFIX') or 'Bearer '
DODJOY_TOKEN_HEADER = 'X-DODJOY-TOKEN'
DODJOY_LOGIN_URL = 'http://auth.dodjoy.com/login?accessKey=1'
DODJOY_BASH_ENV_NAME = 'X_DODJOY_TOKEN'
DODJOY_WINDOWS_ENV_NAME = 'X-DODJOY-TOKEN'
DODJOY_WINDOWS_ENV_NAMES = (DODJOY_BASH_ENV_NAME, DODJOY_WINDOWS_ENV_NAME)
DODJOY_BASHRC_TOKEN_PATTERN = re.compile(
    r'^\s*(?:export\s+)?X_DODJOY_TOKEN=',
)

URL_ARRAY_KEYS = ('mediaUrls', 'imageUrls', 'videoUrls', 'audioUrls', 'urls')
URL_SINGLE_KEYS = ('mediaUrl', 'imageUrl', 'videoUrl', 'audioUrl', 'url')
FAILURE_STATUSES = {'failed', 'error'}
TERMINAL_STATUSES = {
    'completed',
    'complete',
    'success',
    'succeeded',
    'failed',
    'error',
    'cancelled',
    'canceled',
}
RETRYABLE_HTTP_CODES = {429, 500, 502, 503, 504}
DEFAULT_RETRY_COUNT = 3
DEFAULT_RETRY_BASE_INTERVAL = 2.0
IMAGE_URL_SINGLE_KEYS = {
    'imageUrl',
    'sourceImage',
    'sourceImageUrl',
    'lastImageUrl',
    'first_frame_image',
    'last_frame_image',
    'imageReference',
}
IMAGE_URL_LIST_KEYS = {'imageUrls'}


class DownloadMediaError(Exception):
    def __init__(self, message, url=None):
        super().__init__(message)
        self.url = url


def parse_args():
    parser = argparse.ArgumentParser(
        description='Call configurable media APIs to generate media or inspect tasks.',
    )
    parser.add_argument('--base-url', default=DEFAULT_BASE_URL)
    parser.add_argument('--api-key', default=DEFAULT_API_KEY)
    parser.add_argument('--dodjoy-token')
    parser.add_argument(
        '--dodjoy-token-stdin',
        action='store_true',
        help='Read a Dodjoy login key from stdin for this command only.',
    )
    parser.add_argument('--providers-path', default=DEFAULT_PROVIDERS_PATH)
    parser.add_argument('--generate-path', default=DEFAULT_GENERATE_PATH)
    parser.add_argument(
        '--task-path-template',
        default=DEFAULT_TASK_PATH_TEMPLATE,
    )
    parser.add_argument('--openapi-path', default=DEFAULT_OPENAPI_PATH)
    parser.add_argument('--upload-path', default=DEFAULT_UPLOAD_PATH)
    parser.add_argument('--auth-header', default=DEFAULT_AUTH_HEADER)
    parser.add_argument('--auth-prefix', default=DEFAULT_AUTH_PREFIX)

    subparsers = parser.add_subparsers(dest='command', required=True)

    providers = subparsers.add_parser(
        'providers',
        help='List available media providers.',
    )
    providers.add_argument(
        '--include-option-schemas',
        action='store_true',
        help='Merge exact provider option schemas from /api/media/openapi.json into the provider list.',
    )
    providers.add_argument(
        '--provider',
        help='Filter the provider list to one provider id.',
    )
    providers.add_argument('--output-file')

    provider_schema = subparsers.add_parser(
        'provider-schema',
        help='Fetch the exact options schema for one provider from the OpenAPI document.',
    )
    provider_schema.add_argument('--provider', required=True)
    provider_schema.add_argument('--output-file')

    save_dodjoy_token = subparsers.add_parser(
        'save-dodjoy-token',
        help='Persist a Dodjoy login key for future media API calls.',
    )
    save_dodjoy_token.add_argument(
        '--token',
        help='Dodjoy login key to persist. Prefer --token-stdin when scripting.',
    )
    save_dodjoy_token.add_argument(
        '--token-stdin',
        action='store_true',
        help='Read the Dodjoy login key from stdin.',
    )
    save_dodjoy_token.add_argument(
        '--yes',
        action='store_true',
        help='Confirm writing the Dodjoy key to the user environment.',
    )

    generate = subparsers.add_parser(
        'generate',
        help='Call the generate endpoint and optionally wait for completion.',
    )
    generate.add_argument('--provider', required=True)
    generate.add_argument('--prompt', default='')
    generate.add_argument(
        '--prompt-file',
        help='Read prompt text from a file. Recommended on Windows PowerShell for long or multi-line prompts.',
    )
    generate.add_argument('--source')
    generate.add_argument('--options', default='{}')
    generate.add_argument(
        '--options-file',
        help='Read provider options from a JSON file. Recommended on Windows PowerShell to avoid quoting issues.',
    )
    generate.add_argument(
        '--options-file-delete-after',
        action='store_true',
        help='Delete --options-file after the request completes.',
    )
    generate.add_argument('--extra-body', default='{}')
    generate.add_argument('--extra-body-file')
    generate.add_argument(
        '--disable-auto-upload-images',
        action='store_true',
        help='Disable automatic upload of local/base64 image resources in options.imageUrl(s).',
    )
    generate.add_argument('--wait', action='store_true')
    generate.add_argument('--interval', type=float, default=5.0)
    generate.add_argument(
        '--max-interval',
        type=float,
        default=30.0,
        help='Maximum polling interval in seconds when waiting.',
    )
    generate.add_argument('--timeout', type=float, default=600.0)
    generate.add_argument(
        '--output',
        choices=['json', 'urls', 'urls+meta', 'downloads'],
        default='json',
    )
    generate.add_argument(
        '--output-file',
        help='Write command output to a file instead of stdout.',
    )
    generate.add_argument(
        '--download-dir',
        default='.',
        help='Directory used by --output downloads. Defaults to the current working directory.',
    )
    generate.add_argument(
        '--task-query',
        default='{}',
        help='JSON object merged into task status query params when waiting.',
    )
    generate.add_argument('--task-query-file')
    generate.add_argument(
        '--extra-terminal-status',
        nargs='*',
        metavar='STATUS',
        default=[],
        help='Additional terminal status strings to treat as completed.',
    )

    status = subparsers.add_parser(
        'status',
        help='Fetch one task status from the configured task endpoint.',
    )
    status.add_argument('--task-id', required=True)
    status.add_argument('--provider')
    status.add_argument('--task-query', default='{}')
    status.add_argument('--task-query-file')
    status.add_argument(
        '--output',
        choices=['json', 'urls', 'urls+meta', 'downloads'],
        default='json',
    )
    status.add_argument(
        '--output-file',
        help='Write command output to a file instead of stdout.',
    )
    status.add_argument(
        '--download-dir',
        default='.',
        help='Directory used by --output downloads. Defaults to the current working directory.',
    )
    status.add_argument(
        '--extra-terminal-status',
        nargs='*',
        metavar='STATUS',
        default=[],
        help='Additional terminal status strings to treat as completed.',
    )

    wait = subparsers.add_parser(
        'wait',
        help='Poll the configured task endpoint until the task completes or fails.',
    )
    wait.add_argument('--task-id', required=True)
    wait.add_argument('--provider')
    wait.add_argument('--task-query', default='{}')
    wait.add_argument('--task-query-file')
    wait.add_argument('--interval', type=float, default=5.0)
    wait.add_argument(
        '--max-interval',
        type=float,
        default=30.0,
        help='Maximum polling interval in seconds when waiting.',
    )
    wait.add_argument('--timeout', type=float, default=600.0)
    wait.add_argument(
        '--output',
        choices=['json', 'urls', 'urls+meta', 'downloads'],
        default='json',
    )
    wait.add_argument(
        '--output-file',
        help='Write command output to a file instead of stdout.',
    )
    wait.add_argument(
        '--download-dir',
        default='.',
        help='Directory used by --output downloads. Defaults to the current working directory.',
    )
    wait.add_argument(
        '--extra-terminal-status',
        nargs='*',
        metavar='STATUS',
        default=[],
        help='Additional terminal status strings to treat as completed.',
    )

    return parser.parse_args()


def normalize_base_url(base_url):
    return base_url.rstrip('/')


def join_url(base_url, path):
    if path.startswith('http://') or path.startswith('https://'):
        return path
    normalized_path = path if path.startswith('/') else f'/{path}'
    return f'{normalize_base_url(base_url)}{normalized_path}'


def render_task_path(template, task_id):
    quoted_task_id = urllib.parse.quote(str(task_id), safe='')
    if '{taskId}' in template or '{task_id}' in template:
        return (
            template.replace('{taskId}', quoted_task_id).replace(
                '{task_id}',
                quoted_task_id,
            )
        )
    suffix = '' if template.endswith('/') else '/'
    return f'{template}{suffix}{quoted_task_id}'


def quote_bash_value(value):
    return "'" + value.replace("'", "'\"'\"'") + "'"


def persist_dodjoy_token_windows(token):
    import ctypes

    for env_name in DODJOY_WINDOWS_ENV_NAMES:
        os.environ[env_name] = token
        result = ctypes.windll.kernel32.SetEnvironmentVariableW(
            env_name,
            token,
        )
        if not result:
            raise OSError(f'SetEnvironmentVariableW failed for {env_name}.')
    try:
        import winreg

        with winreg.OpenKey(
            winreg.HKEY_CURRENT_USER,
            'Environment',
            0,
            winreg.KEY_SET_VALUE,
        ) as key:
            for env_name in DODJOY_WINDOWS_ENV_NAMES:
                winreg.SetValueEx(
                    key,
                    env_name,
                    0,
                    winreg.REG_SZ,
                    token,
                )
    except OSError as exc:
        raise OSError(
            'Failed to persist Dodjoy token in user environment: '
            f'{exc}',
        ) from exc


def persist_dodjoy_token_bashrc(token):
    os.environ[DODJOY_BASH_ENV_NAME] = token
    bashrc_path = os.path.expanduser('~/.bashrc')
    line = f'export {DODJOY_BASH_ENV_NAME}={quote_bash_value(token)}\n'
    lines = []
    if os.path.exists(bashrc_path):
        with open(bashrc_path, 'r', encoding='utf-8') as handle:
            lines = handle.readlines()

    replaced = False
    updated_lines = []
    for existing_line in lines:
        if DODJOY_BASHRC_TOKEN_PATTERN.match(existing_line):
            if not replaced:
                updated_lines.append(line)
                replaced = True
            continue
        updated_lines.append(existing_line)

    if not replaced:
        if updated_lines and not updated_lines[-1].endswith('\n'):
            updated_lines[-1] = f'{updated_lines[-1]}\n'
        updated_lines.append(line)

    with open(bashrc_path, 'w', encoding='utf-8', newline='\n') as handle:
        handle.writelines(updated_lines)


def persist_dodjoy_token(token):
    try:
        if os.name == 'nt':
            persist_dodjoy_token_windows(token)
            print(
                f'INFO: Saved {DODJOY_BASH_ENV_NAME} and {DODJOY_WINDOWS_ENV_NAME} to the Windows user environment. Restart terminals to use it automatically.',
                file=sys.stderr,
                flush=True,
            )
            return
        persist_dodjoy_token_bashrc(token)
        print(
            f'INFO: Saved {DODJOY_BASH_ENV_NAME} to ~/.bashrc. Start a new shell or run source ~/.bashrc to use it automatically.',
            file=sys.stderr,
            flush=True,
        )
    except OSError as exc:
        raise SystemExit(f'Failed to persist Dodjoy token: {exc}') from exc


def prompt_for_dodjoy_token():
    message = (
        'Missing auth. Set MEDIA_API_KEY, set X-DODJOY-TOKEN on Windows, '
        'set X_DODJOY_TOKEN on Linux/macOS, or pass --api-key. '
        f'To get a Dodjoy key, open {DODJOY_LOGIN_URL}, log in, copy the key, '
        "then set it locally or paste it for this run only. PowerShell: "
        "$env:X_DODJOY_TOKEN='<copied-key>'. bash: "
        "export X_DODJOY_TOKEN='<copied-key>'. If the user already pasted the "
        'key into chat, pipe it with --dodjoy-token-stdin for this command '
        'and do not print the token. Persisting the key requires an explicit '
        'user confirmation and save-dodjoy-token --token-stdin --yes.'
    )
    if not sys.stdin.isatty():
        raise SystemExit(message)
    print(
        f'{message}\nPaste the key below to use it for this run only.',
        file=sys.stderr,
        flush=True,
    )
    try:
        token = getpass.getpass('Dodjoy key: ').strip()
    except (EOFError, KeyboardInterrupt) as exc:
        raise SystemExit('Dodjoy login key input was cancelled.') from exc
    if not token:
        raise SystemExit('Dodjoy login key cannot be empty.')
    return token


def read_dodjoy_token_for_save(args):
    if args.token_stdin:
        token = sys.stdin.read().strip()
    else:
        token = (args.token or '').strip()
    if not token:
        raise SystemExit(
            'Missing Dodjoy token. Pass --token or pipe it with --token-stdin.',
        )
    return token


def get_env_dodjoy_token():
    return (
        os.environ.get(DODJOY_BASH_ENV_NAME)
        or os.environ.get(DODJOY_WINDOWS_ENV_NAME)
        or ''
    ).strip()


def resolve_auth(args):
    api_key = (getattr(args, 'api_key', None) or '').strip()
    dodjoy_token = (getattr(args, 'dodjoy_token', None) or '').strip()
    dodjoy_token_stdin = getattr(args, 'dodjoy_token_stdin', False)
    if api_key:
        args.api_key = api_key
        args.dodjoy_token = None
        return
    if dodjoy_token_stdin:
        token = sys.stdin.read().strip()
        if not token:
            raise SystemExit(
                'Missing Dodjoy token on stdin for --dodjoy-token-stdin.',
            )
        args.api_key = None
        args.dodjoy_token = token
        return
    if dodjoy_token:
        args.api_key = None
        args.dodjoy_token = dodjoy_token
        return
    env_dodjoy_token = get_env_dodjoy_token()
    if env_dodjoy_token:
        args.api_key = None
        args.dodjoy_token = env_dodjoy_token
        return
    args.api_key = None
    args.dodjoy_token = prompt_for_dodjoy_token()


def require_base_url(args):
    if args.base_url:
        return
    raise SystemExit(
        'Missing base URL. Set MEDIA_API_BASE_URL or pass --base-url.',
    )


def load_json_file(path, label):
    # Accept UTF-8 files with or without BOM. PowerShell 5.1 commonly writes BOM.
    with open(path, 'r', encoding='utf-8-sig') as handle:
        try:
            return json.load(handle)
        except json.JSONDecodeError as exc:
            raise SystemExit(f'Invalid {label} JSON file: {exc}') from exc


def load_json_value(raw_value, raw_file, label):
    if raw_file:
        return load_json_file(raw_file, label)
    try:
        return json.loads(raw_value)
    except json.JSONDecodeError as exc:
        raise SystemExit(f'Invalid {label} JSON: {exc}') from exc


def load_json_object(raw_value, raw_file, label):
    value = load_json_value(raw_value, raw_file, label)
    if isinstance(value, dict):
        return value
    raise SystemExit(f'{label} must be a JSON object.')


def load_prompt(prompt_arg, prompt_file_arg):
    if prompt_file_arg:
        try:
            with open(prompt_file_arg, 'r', encoding='utf-8-sig') as handle:
                return handle.read().strip()
        except OSError as exc:
            raise SystemExit(f'Cannot read --prompt-file: {exc}') from exc
    return prompt_arg


def looks_like_http_url(value):
    if not isinstance(value, str):
        return False
    lowered = value.strip().lower()
    return lowered.startswith('http://') or lowered.startswith('https://')


def detect_image_mime_from_bytes(payload):
    if not payload:
        return None
    if payload.startswith(b'\x89PNG\r\n\x1a\n'):
        return 'image/png'
    if payload.startswith(b'\xff\xd8\xff'):
        return 'image/jpeg'
    if payload.startswith((b'GIF87a', b'GIF89a')):
        return 'image/gif'
    if payload.startswith(b'BM'):
        return 'image/bmp'
    if payload.startswith(b'II*\x00') or payload.startswith(b'MM\x00*'):
        return 'image/tiff'
    if (
        len(payload) >= 12
        and payload[:4] == b'RIFF'
        and payload[8:12] == b'WEBP'
    ):
        return 'image/webp'
    probe = payload[:256].lstrip().lower()
    if probe.startswith(b'<?xml') or probe.startswith(b'<svg'):
        return 'image/svg+xml'
    return None


def extension_for_mime(mime_type):
    guessed = mimetypes.guess_extension(mime_type or '') or ''
    if guessed == '.jpe':
        return '.jpg'
    if guessed:
        return guessed
    return '.png'


def file_url_to_path(value):
    parsed = urllib.parse.urlparse(value)
    if parsed.scheme != 'file':
        return None
    path = urllib.parse.unquote(parsed.path)
    if os.name == 'nt' and len(path) >= 3 and path[0] == '/' and path[2] == ':':
        path = path[1:]
    return path


def normalize_image_resource(value):
    if not isinstance(value, str):
        return None
    resource = value.strip()
    if not resource:
        return None
    if looks_like_http_url(resource):
        return None

    local_path = None
    if resource.lower().startswith('file://'):
        local_path = file_url_to_path(resource)
    elif os.path.exists(resource):
        local_path = resource

    if local_path and os.path.isfile(local_path):
        with open(local_path, 'rb') as handle:
            payload = handle.read()
        base_name = os.path.basename(local_path) or f'image-{uuid.uuid4().hex[:8]}'
        guessed_mime = mimetypes.guess_type(base_name)[0]
        mime_type = (
            guessed_mime
            if guessed_mime and guessed_mime.startswith('image/')
            else detect_image_mime_from_bytes(payload)
        )
        if not mime_type:
            raise SystemExit(
                f'Image upload requires an image file: {os.path.abspath(local_path)}',
            )
        return {
            'bytes': payload,
            'fileName': base_name,
            'mimeType': mime_type,
            'cacheKey': f'path:{os.path.abspath(local_path)}',
            'source': os.path.abspath(local_path),
        }

    lowered = resource.lower()
    if lowered.startswith('data:image/'):
        comma_index = resource.find(',')
        if comma_index <= 0:
            raise SystemExit('Invalid data URI image resource.')
        meta = resource[5:comma_index]
        payload_text = resource[comma_index + 1:]
        mime_type = meta.split(';', 1)[0]
        if ';base64' in meta:
            try:
                payload = base64.b64decode(payload_text, validate=True)
            except (binascii.Error, ValueError) as exc:
                raise SystemExit(f'Invalid base64 image data URI: {exc}') from exc
        else:
            payload = urllib.parse.unquote_to_bytes(payload_text)
        file_name = (
            f'upload-image-{uuid.uuid4().hex[:8]}'
            f'{extension_for_mime(mime_type)}'
        )
        digest = hashlib.sha1(payload).hexdigest()
        return {
            'bytes': payload,
            'fileName': file_name,
            'mimeType': mime_type,
            'cacheKey': f'data:{digest}',
            'source': 'data-uri',
        }

    compact = ''.join(resource.split())
    if len(compact) >= 64:
        padded = compact + ('=' * ((4 - len(compact) % 4) % 4))
        try:
            payload = base64.b64decode(padded, validate=True)
        except (binascii.Error, ValueError):
            payload = None
        if payload:
            mime_type = detect_image_mime_from_bytes(payload)
            if mime_type:
                digest = hashlib.sha1(payload).hexdigest()
                file_name = (
                    f'upload-image-{digest[:8]}'
                    f'{extension_for_mime(mime_type)}'
                )
                return {
                    'bytes': payload,
                    'fileName': file_name,
                    'mimeType': mime_type,
                    'cacheKey': f'base64:{digest}',
                    'source': 'base64-image',
                }

    return None


def build_headers(args):
    headers = {
        'Accept': 'application/json',
    }
    if args.api_key:
        headers[args.auth_header] = f'{args.auth_prefix}{args.api_key}'
    if getattr(args, 'dodjoy_token', None):
        headers[DODJOY_TOKEN_HEADER] = args.dodjoy_token
    return headers


def request_json(method, url, args, payload=None, retries=DEFAULT_RETRY_COUNT):
    headers = build_headers(args)
    data = None
    if payload is not None:
        headers['Content-Type'] = 'application/json'
        data = json.dumps(payload).encode('utf-8')

    last_exc = None
    for attempt in range(retries + 1):
        if attempt > 0:
            backoff = DEFAULT_RETRY_BASE_INTERVAL * (2 ** (attempt - 1))
            print(
                f'INFO: Retrying request (attempt {attempt}/{retries}) after {backoff:.1f}s ...',
                file=sys.stderr,
                flush=True,
            )
            time.sleep(backoff)

        request = urllib.request.Request(
            url,
            data=data,
            headers=headers,
            method=method,
        )
        try:
            with urllib.request.urlopen(request) as response:
                body_text = response.read().decode('utf-8')
                body = json.loads(body_text) if body_text else {}
                return response.status, body
        except urllib.error.HTTPError as exc:
            body_text = exc.read().decode('utf-8', errors='replace')
            try:
                body = json.loads(body_text) if body_text else {}
            except json.JSONDecodeError:
                body = {'message': body_text}
            message = body.get('message') or body.get('error') or body_text
            if exc.code in RETRYABLE_HTTP_CODES and attempt < retries:
                last_exc = exc
                print(
                    f'INFO: HTTP {exc.code} (retryable): {message}',
                    file=sys.stderr,
                    flush=True,
                )
                continue
            raise SystemExit(f'HTTP {exc.code}: {message}') from exc
        except urllib.error.URLError as exc:
            if attempt < retries:
                last_exc = exc
                print(
                    f'INFO: Request error (retryable): {exc.reason}',
                    file=sys.stderr,
                    flush=True,
                )
                continue
            raise SystemExit(f'Request failed: {exc.reason}') from exc

    raise SystemExit(f'Request failed after {retries} retries: {last_exc}')


def request_json_raw(
    method,
    url,
    args,
    body,
    content_type,
    retries=DEFAULT_RETRY_COUNT,
):
    headers = build_headers(args)
    headers['Content-Type'] = content_type

    last_exc = None
    for attempt in range(retries + 1):
        if attempt > 0:
            backoff = DEFAULT_RETRY_BASE_INTERVAL * (2 ** (attempt - 1))
            print(
                f'INFO: Retrying request (attempt {attempt}/{retries}) after {backoff:.1f}s ...',
                file=sys.stderr,
                flush=True,
            )
            time.sleep(backoff)

        request = urllib.request.Request(
            url,
            data=body,
            headers=headers,
            method=method,
        )
        try:
            with urllib.request.urlopen(request) as response:
                body_text = response.read().decode('utf-8')
                parsed_body = json.loads(body_text) if body_text else {}
                return response.status, parsed_body
        except urllib.error.HTTPError as exc:
            body_text = exc.read().decode('utf-8', errors='replace')
            try:
                parsed_body = json.loads(body_text) if body_text else {}
            except json.JSONDecodeError:
                parsed_body = {'message': body_text}
            message = (
                parsed_body.get('message') or parsed_body.get('error') or body_text
            )
            if exc.code in RETRYABLE_HTTP_CODES and attempt < retries:
                last_exc = exc
                print(
                    f'INFO: HTTP {exc.code} (retryable): {message}',
                    file=sys.stderr,
                    flush=True,
                )
                continue
            raise SystemExit(f'HTTP {exc.code}: {message}') from exc
        except urllib.error.URLError as exc:
            if attempt < retries:
                last_exc = exc
                print(
                    f'INFO: Request error (retryable): {exc.reason}',
                    file=sys.stderr,
                    flush=True,
                )
                continue
            raise SystemExit(f'Request failed: {exc.reason}') from exc

    raise SystemExit(f'Request failed after {retries} retries: {last_exc}')


def extract_upload_url(payload):
    def visit(node, depth):
        if depth > 4:
            return None
        if isinstance(node, dict):
            for key in ('url', 'downloadUrl', 'fileUrl'):
                candidate = node.get(key)
                if isinstance(candidate, str) and candidate.strip():
                    return candidate.strip()
            for key in ('data', 'result', 'file'):
                candidate = visit(node.get(key), depth + 1)
                if candidate:
                    return candidate
        return None

    return visit(payload, 0)


def build_multipart_body(file_name, mime_type, payload):
    boundary = f'----MediaApiBoundary{uuid.uuid4().hex}'
    prefix = (
        f'--{boundary}\r\n'
        f'Content-Disposition: form-data; name="file"; filename="{file_name}"\r\n'
        f'Content-Type: {mime_type}\r\n\r\n'
    ).encode('utf-8')
    suffix = f'\r\n--{boundary}--\r\n'.encode('utf-8')
    return boundary, prefix + payload + suffix


def upload_image_resource(raw_value, args, upload_cache):
    resource = normalize_image_resource(raw_value)
    if not resource:
        return raw_value

    cache_key = resource['cacheKey']
    if cache_key in upload_cache:
        return upload_cache[cache_key]

    upload_url = join_url(args.base_url, args.upload_path)
    boundary, body = build_multipart_body(
        resource['fileName'],
        resource['mimeType'],
        resource['bytes'],
    )
    _, upload_result = request_json_raw(
        'POST',
        upload_url,
        args,
        body,
        f'multipart/form-data; boundary={boundary}',
    )
    uploaded_url = extract_upload_url(upload_result)
    if not uploaded_url:
        raise SystemExit(
            'Image upload succeeded but response did not include a URL.',
        )
    resolved_url = (
        uploaded_url
        if looks_like_http_url(uploaded_url)
        else join_url(args.base_url, uploaded_url)
    )
    upload_cache[cache_key] = resolved_url
    print(
        f'INFO: Uploaded image resource ({resource["source"]}) -> {resolved_url}',
        file=sys.stderr,
        flush=True,
    )
    return resolved_url


def normalize_options_image_resources(node, args, upload_cache, parent_key=None):
    if isinstance(node, dict):
        normalized = {}
        for key, value in node.items():
            if key in IMAGE_URL_SINGLE_KEYS and isinstance(value, str):
                normalized[key] = upload_image_resource(value, args, upload_cache)
                continue
            if key in IMAGE_URL_LIST_KEYS and isinstance(value, list):
                normalized[key] = [
                    upload_image_resource(item, args, upload_cache)
                    if isinstance(item, str)
                    else normalize_options_image_resources(
                        item,
                        args,
                        upload_cache,
                        parent_key=key,
                    )
                    for item in value
                ]
                continue
            normalized[key] = normalize_options_image_resources(
                value,
                args,
                upload_cache,
                parent_key=key,
            )
        return normalized

    if isinstance(node, list):
        normalized = []
        for item in node:
            if parent_key in IMAGE_URL_LIST_KEYS and isinstance(item, str):
                normalized.append(upload_image_resource(item, args, upload_cache))
            else:
                normalized.append(
                    normalize_options_image_resources(
                        item,
                        args,
                        upload_cache,
                        parent_key=parent_key,
                    ),
                )
        return normalized

    return node


def preprocess_generate_options(options, args):
    if getattr(args, 'disable_auto_upload_images', False):
        return options
    upload_cache = {}
    return normalize_options_image_resources(options, args, upload_cache)


def get_provider_list(body):
    if isinstance(body, dict):
        providers = body.get('providers')
        if isinstance(providers, list):
            return providers
        data = body.get('data')
        if isinstance(data, dict) and isinstance(data.get('providers'), list):
            return data['providers']
    return []


def resolve_json_pointer(document, pointer):
    if not pointer.startswith('#/'):
        raise SystemExit(f'Unsupported $ref pointer: {pointer}')

    current = document
    for token in pointer[2:].split('/'):
        token = token.replace('~1', '/').replace('~0', '~')
        if isinstance(current, dict) and token in current:
            current = current[token]
        else:
            raise SystemExit(f'Cannot resolve $ref pointer: {pointer}')
    return current


def resolve_openapi_refs(node, document):
    if isinstance(node, dict):
        if '$ref' in node and isinstance(node['$ref'], str):
            resolved = resolve_json_pointer(document, node['$ref'])
            merged = copy.deepcopy(resolved)
            for key, value in node.items():
                if key != '$ref':
                    merged[key] = resolve_openapi_refs(value, document)
            return resolve_openapi_refs(merged, document)
        return {
            key: resolve_openapi_refs(value, document)
            for key, value in node.items()
        }
    if isinstance(node, list):
        return [resolve_openapi_refs(item, document) for item in node]
    return node


def get_generate_request_schema(openapi_document):
    path_item = openapi_document.get('paths', {}).get('/api/media/generate', {})
    post = path_item.get('post', {})
    schema = (
        post.get('requestBody', {})
        .get('content', {})
        .get('application/json', {})
        .get('schema')
    )
    if isinstance(schema, dict):
        return schema

    path_count = len(openapi_document.get('paths', {}))
    raise SystemExit(
        'OpenAPI document does not expose /api/media/generate request schema. '
        f'Found {path_count} path(s). This environment may be serving a stub '
        '/api/media/openapi.json. Fall back to /api/media/providers plus '
        'references/provider-rules.md, or use an environment with the full '
        'media OpenAPI document.',
    )


def get_options_variants_from_openapi(openapi_document):
    request_schema = get_generate_request_schema(openapi_document)
    resolved_request_schema = resolve_openapi_refs(request_schema, openapi_document)
    options_schema = resolved_request_schema.get('properties', {}).get('options')
    if not isinstance(options_schema, dict):
        raise SystemExit(
            'OpenAPI document does not expose a request.options schema. '
            'Fall back to references/provider-rules.md if exact runtime schema '
            'extraction is unavailable in this environment.',
        )

    resolved_options_schema = resolve_openapi_refs(options_schema, openapi_document)
    variants = resolved_options_schema.get('oneOf')
    if not isinstance(variants, list):
        variants = resolved_options_schema.get('anyOf')
    if not isinstance(variants, list) or len(variants) == 0:
        raise SystemExit(
            'OpenAPI document does not expose provider-specific options variants. '
            'Fall back to references/provider-rules.md if exact runtime schema '
            'extraction is unavailable in this environment.',
        )
    return variants


def extract_provider_id_from_variant(variant):
    properties = variant.get('properties', {})
    provider_schema = properties.get('provider', {})
    if isinstance(provider_schema, dict):
        enum_values = provider_schema.get('enum')
        if isinstance(enum_values, list) and len(enum_values) > 0:
            provider = enum_values[0]
            if isinstance(provider, str) and provider:
                return provider
        const_value = provider_schema.get('const')
        if isinstance(const_value, str) and const_value:
            return const_value
    return None


def strip_provider_from_options_schema(variant):
    schema = copy.deepcopy(variant)
    properties = schema.get('properties')
    if isinstance(properties, dict):
        properties.pop('provider', None)
    required = schema.get('required')
    if isinstance(required, list):
        schema['required'] = [item for item in required if item != 'provider']
        if len(schema['required']) == 0:
            schema.pop('required', None)
    return schema


def get_provider_schema_map_from_openapi(openapi_document):
    provider_schema_map = {}
    for variant in get_options_variants_from_openapi(openapi_document):
        resolved_variant = resolve_openapi_refs(variant, openapi_document)
        provider_id = extract_provider_id_from_variant(resolved_variant)
        if not provider_id:
            continue
        provider_schema_map[provider_id] = strip_provider_from_options_schema(
            resolved_variant,
        )
    if not provider_schema_map:
        raise SystemExit(
            'OpenAPI document did not yield any provider-specific options schemas.',
        )
    return provider_schema_map


def get_openapi_document(args):
    require_base_url(args)
    resolve_auth(args)
    url = join_url(args.base_url, args.openapi_path)
    _, body = request_json('GET', url, args)
    if not isinstance(body, dict):
        raise SystemExit('OpenAPI response is not a JSON object.')
    return body


def emit_text(text, output_file=None):
    if output_file:
        with open(
            output_file,
            'w',
            encoding='utf-8',
            newline='\n',
        ) as handle:
            handle.write(text)
        return
    print(text, end='')


def extract_media_urls(value):
    urls = []
    seen = set()

    def add_url(item):
        if not isinstance(item, str) or not item or item in seen:
            return
        seen.add(item)
        urls.append(item)

    def visit(node, depth):
        if depth > 4:
            return
        if isinstance(node, dict):
            for key in URL_ARRAY_KEYS:
                raw_value = node.get(key)
                if isinstance(raw_value, list):
                    for item in raw_value:
                        add_url(item)
            for key in URL_SINGLE_KEYS:
                add_url(node.get(key))
            for key in ('task', 'result', 'data', 'output', 'outputs'):
                if key in node:
                    visit(node[key], depth + 1)
        elif isinstance(node, list):
            for item in node[:20]:
                visit(item, depth + 1)

    visit(value, 0)
    return urls


def ensure_download_dir(download_dir):
    resolved_dir = os.path.abspath(download_dir or '.')
    if os.path.exists(resolved_dir) and not os.path.isdir(resolved_dir):
        raise SystemExit(f'Download directory is not a directory: {resolved_dir}')
    os.makedirs(resolved_dir, exist_ok=True)
    return resolved_dir


def sanitize_filename(file_name):
    invalid_chars = '<>:"/\\|?*'
    sanitized = ''.join(
        '_' if ch in invalid_chars or ord(ch) < 32 else ch
        for ch in file_name
    )
    sanitized = sanitized.rstrip(' .')
    return sanitized or 'media'


def guess_file_name(url, index, content_type):
    parsed_url = urllib.parse.urlparse(url)
    raw_name = os.path.basename(urllib.parse.unquote(parsed_url.path))
    base_name, extension = os.path.splitext(raw_name)
    if not base_name:
        base_name = f'media-{index:02d}'

    if not extension and content_type:
        media_type = content_type.split(';', 1)[0].strip().lower()
        guessed_extension = mimetypes.guess_extension(media_type) or ''
        if guessed_extension == '.jpe':
            guessed_extension = '.jpg'
        extension = guessed_extension

    candidate = f'{base_name}{extension}'
    return sanitize_filename(candidate)


def resolve_unique_path(download_dir, file_name):
    base_name, extension = os.path.splitext(file_name)
    candidate_path = os.path.join(download_dir, file_name)
    counter = 2
    while os.path.exists(candidate_path):
        candidate_path = os.path.join(
            download_dir,
            f'{base_name}-{counter}{extension}',
        )
        counter += 1
    return candidate_path


def build_download_headers(url, args):
    parsed_url = urllib.parse.urlparse(url)
    base_url = urllib.parse.urlparse(normalize_base_url(args.base_url))
    if parsed_url.netloc != base_url.netloc:
        return {}
    return build_headers(args)


def download_media_files(urls, args):
    download_dir = ensure_download_dir(getattr(args, 'download_dir', '.'))
    downloaded_files = []

    for index, original_url in enumerate(urls, start=1):
        resolved_url = join_url(args.base_url, original_url)
        request = urllib.request.Request(
            resolved_url,
            headers=build_download_headers(resolved_url, args),
            method='GET',
        )
        try:
            with urllib.request.urlopen(request) as response:
                content_type = response.headers.get('Content-Type', '')
                file_name = guess_file_name(resolved_url, index, content_type)
                file_path = resolve_unique_path(download_dir, file_name)
                with open(file_path, 'wb') as handle:
                    shutil.copyfileobj(response, handle)
        except urllib.error.HTTPError as exc:
            raise DownloadMediaError(
                f'Failed to download media from {resolved_url}: HTTP {exc.code}.',
                url=resolved_url,
            ) from exc
        except urllib.error.URLError as exc:
            raise DownloadMediaError(
                f'Failed to download media from {resolved_url}: {exc.reason}.',
                url=resolved_url,
            ) from exc

        downloaded_files.append(
            {
                'fileName': os.path.basename(file_path),
                'path': file_path,
                'sizeBytes': os.path.getsize(file_path),
                'url': resolved_url,
            }
        )

    return {
        'downloadDir': download_dir,
        'files': downloaded_files,
        'urls': [item['url'] for item in downloaded_files],
    }


def normalize_status(raw_status):
    if not isinstance(raw_status, str):
        return ''
    return raw_status.strip().lower().replace(' ', '_').replace('-', '_')


def is_terminal_status(raw_status, extra_terminal=None):
    normalized = normalize_status(raw_status)
    if normalized in TERMINAL_STATUSES:
        return True
    if extra_terminal:
        for status in extra_terminal:
            if normalized == normalize_status(status):
                return True
    return False


def get_task_body(raw_body):
    if isinstance(raw_body, dict) and isinstance(raw_body.get('task'), dict):
        return raw_body['task']
    return {}


def resolve_task_id(raw_body):
    task = get_task_body(raw_body)
    if isinstance(raw_body, dict):
        top_level = raw_body
    else:
        top_level = {}
    for candidate in (
        task.get('taskId'),
        task.get('id'),
        top_level.get('taskId'),
        top_level.get('id'),
    ):
        if isinstance(candidate, str) and candidate:
            return candidate
    return None


def build_task_query(args, provider=None):
    query = load_json_object(
        args.task_query,
        getattr(args, 'task_query_file', None),
        '--task-query',
    )
    if provider and 'provider' not in query:
        query['provider'] = provider
    return query


def get_task(args, task_id, provider=None):
    task_path = render_task_path(args.task_path_template, task_id)
    url = join_url(args.base_url, task_path)
    query = build_task_query(args, provider)
    if query:
        encoded_query = urllib.parse.urlencode(query, doseq=True)
        joiner = '&' if urllib.parse.urlparse(url).query else '?'
        url = f'{url}{joiner}{encoded_query}'
    _, body = request_json('GET', url, args)
    return body


def extract_failure_reason(body):
    candidates = []
    if isinstance(body, dict):
        for key in ('message', 'error', 'reason', 'errorMessage', 'err'):
            value = body.get(key)
            if isinstance(value, str) and value:
                candidates.append(value)
    task = get_task_body(body)
    for key in ('message', 'error', 'reason', 'errorMessage'):
        value = task.get(key)
        if isinstance(value, str) and value:
            candidates.append(value)
    return candidates[0] if candidates else None


def print_result(body, args, output_file=None, provider=None):
    if args.output == 'urls':
        emit_text(
            json.dumps(extract_media_urls(body), ensure_ascii=False, indent=2)
            + '\n',
            output_file=output_file,
        )
        return
    if args.output == 'urls+meta':
        emit_text(
            json.dumps(
                {
                    'urls': extract_media_urls(body),
                    'taskId': resolve_task_id(body),
                    'provider': provider,
                },
                ensure_ascii=False,
                indent=2,
            )
            + '\n',
            output_file=output_file,
        )
        return
    if args.output == 'downloads':
        urls = extract_media_urls(body)
        if not urls:
            emit_text(
                json.dumps(body, ensure_ascii=False, indent=2) + '\n',
                output_file=output_file,
            )
            return
        try:
            download_result = download_media_files(urls, args)
        except DownloadMediaError as exc:
            emit_text(
                json.dumps(
                    {
                        'success': False,
                        'stage': 'download',
                        'taskId': resolve_task_id(body),
                        'provider': provider,
                        'urls': urls,
                        'failedUrl': exc.url,
                        'error': str(exc),
                    },
                    ensure_ascii=False,
                    indent=2,
                )
                + '\n',
                output_file=output_file,
            )
            raise SystemExit(1) from exc
        emit_text(
            json.dumps(
                download_result,
                ensure_ascii=False,
                indent=2,
            )
            + '\n',
            output_file=output_file,
        )
        return
    emit_text(
        json.dumps(body, ensure_ascii=False, indent=2) + '\n',
        output_file=output_file,
    )


def wait_for_task(args, task_id, provider=None):
    extra_terminal = getattr(args, 'extra_terminal_status', None) or []
    start = time.time()
    last_status = None
    attempt = 0
    while True:
        body = get_task(args, task_id, provider=provider)
        task = get_task_body(body)
        status = task.get('status') or body.get('status')
        normalized = normalize_status(status)
        elapsed = time.time() - start
        if normalized != last_status:
            print(
                f'INFO: task {task_id}: {status or "unknown"} (elapsed: {elapsed:.0f}s)',
                file=sys.stderr,
                flush=True,
            )
            last_status = normalized
        elif attempt % 6 == 5:
            print(
                f'INFO: task {task_id}: still {status or "unknown"} (elapsed: {elapsed:.0f}s / timeout: {args.timeout:.0f}s)',
                file=sys.stderr,
                flush=True,
            )

        if is_terminal_status(status, extra_terminal):
            if normalized in FAILURE_STATUSES:
                reason = extract_failure_reason(body)
                if reason:
                    print(
                        f'ERROR: task {task_id}: failed - {reason}',
                        file=sys.stderr,
                        flush=True,
                    )
                raise SystemExit(1)
            return body

        if not status and extract_media_urls(body):
            return body

        remaining = args.timeout - elapsed
        if remaining <= 0:
            raise SystemExit(f'Timeout waiting for task {task_id}.')

        backoff_interval = min(
            args.interval * (1.5**attempt),
            getattr(args, 'max_interval', 30.0),
        )
        time.sleep(min(backoff_interval, remaining))
        attempt += 1


def cleanup_options_file(args):
    if getattr(args, 'options_file_delete_after', False) and args.options_file:
        try:
            os.remove(args.options_file)
        except OSError:
            pass


def command_providers(args):
    require_base_url(args)
    resolve_auth(args)
    url = join_url(args.base_url, args.providers_path)
    _, body = request_json('GET', url, args)

    providers = get_provider_list(body)
    if args.provider:
        providers = [
            provider
            for provider in providers
            if provider.get('id') == args.provider
        ]

    if args.include_option_schemas:
        schema_error = ''
        try:
            provider_schema_map = get_provider_schema_map_from_openapi(
                get_openapi_document(args),
            )
        except SystemExit as exc:
            provider_schema_map = {}
            schema_error = str(exc)
        merged_providers = []
        for provider in providers:
            provider_id = provider.get('id')
            merged_provider = dict(provider)
            merged_provider['optionsSchema'] = provider_schema_map.get(provider_id)
            merged_provider['optionsSchemaAvailable'] = (
                provider_id in provider_schema_map
            )
            merged_providers.append(merged_provider)
        base_body = body if isinstance(body, dict) else {}
        body = {
            **base_body,
            'providers': merged_providers,
            'schemaSource': args.openapi_path,
            'schemaStatus': 'degraded' if schema_error else 'ok',
        }
        if schema_error:
            body['schemaError'] = schema_error
    elif args.provider:
        body = {
            **body,
            'providers': providers,
        }

    emit_text(
        json.dumps(body, ensure_ascii=False, indent=2) + '\n',
        output_file=args.output_file,
    )


def command_provider_schema(args):
    provider_schema_map = get_provider_schema_map_from_openapi(
        get_openapi_document(args),
    )
    if args.provider not in provider_schema_map:
        raise SystemExit(
            f'Provider schema not found in OpenAPI document: {args.provider}',
        )
    emit_text(
        json.dumps(
            {
                'success': True,
                'provider': args.provider,
                'schemaSource': args.openapi_path,
                'optionsSchema': provider_schema_map[args.provider],
            },
            ensure_ascii=False,
            indent=2,
        )
        + '\n',
        output_file=args.output_file,
    )


def command_save_dodjoy_token(args):
    if not getattr(args, 'yes', False):
        raise SystemExit(
            'Refusing to persist Dodjoy token without explicit confirmation. '
            'Ask the user to confirm saving it, then rerun with --yes.',
        )
    token = read_dodjoy_token_for_save(args)
    persist_dodjoy_token(token)
    emit_text(
        json.dumps(
            {
                'success': True,
                'saved': True,
                'env': (
                    list(DODJOY_WINDOWS_ENV_NAMES)
                    if os.name == 'nt'
                    else [DODJOY_BASH_ENV_NAME]
                ),
            },
            ensure_ascii=False,
            indent=2,
        )
        + '\n',
    )


def command_generate(args):
    require_base_url(args)
    resolve_auth(args)
    output_file = getattr(args, 'output_file', None)

    try:
        prompt = load_prompt(args.prompt, getattr(args, 'prompt_file', None))
        options = load_json_object(args.options, args.options_file, '--options')
        options = preprocess_generate_options(options, args)
        extra_body = load_json_object(
            args.extra_body,
            args.extra_body_file,
            '--extra-body',
        )
        payload = dict(extra_body)
        payload['provider'] = args.provider
        payload['prompt'] = prompt
        payload['options'] = options
        if args.source is not None:
            payload['source'] = args.source

        url = join_url(args.base_url, args.generate_path)
        _, body = request_json('POST', url, args, payload=payload)

        if not args.wait:
            print_result(
                body,
                args,
                output_file=output_file,
                provider=args.provider,
            )
            return

        if extract_media_urls(body) and not resolve_task_id(body):
            print_result(
                body,
                args,
                output_file=output_file,
                provider=args.provider,
            )
            return

        task_id = resolve_task_id(body)
        if not task_id:
            raise SystemExit('The generate response did not include a task id.')

        task = get_task_body(body)
        status = task.get('status') or body.get('status')
        if is_terminal_status(status, args.extra_terminal_status):
            print_result(
                body,
                args,
                output_file=output_file,
                provider=args.provider,
            )
            return

        final_body = wait_for_task(args, task_id, provider=args.provider)
        print_result(
            final_body,
            args,
            output_file=output_file,
            provider=args.provider,
        )
    finally:
        cleanup_options_file(args)


def command_status(args):
    require_base_url(args)
    resolve_auth(args)
    body = get_task(args, args.task_id, provider=args.provider)
    print_result(
        body,
        args,
        output_file=getattr(args, 'output_file', None),
        provider=args.provider,
    )


def command_wait(args):
    require_base_url(args)
    resolve_auth(args)
    body = wait_for_task(args, args.task_id, provider=args.provider)
    print_result(
        body,
        args,
        output_file=getattr(args, 'output_file', None),
        provider=args.provider,
    )


def main():
    args = parse_args()
    if args.command == 'providers':
        command_providers(args)
        return
    if args.command == 'provider-schema':
        command_provider_schema(args)
        return
    if args.command == 'save-dodjoy-token':
        command_save_dodjoy_token(args)
        return
    if args.command == 'generate':
        command_generate(args)
        return
    if args.command == 'status':
        command_status(args)
        return
    if args.command == 'wait':
        command_wait(args)
        return
    raise SystemExit(f'Unsupported command: {args.command}')


if __name__ == '__main__':
    main()
