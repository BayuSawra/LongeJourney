#!/usr/bin/env python3
"""MCP integration acceptance in an isolated editor/project/user-data directory (Windows)."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
MCP = 'res://addons/godot_dotnet_mcp/plugin.cfg'


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def editor_executable(engine: str) -> str:
    path = Path(engine)
    if path.name.endswith("_console.exe"):
        path = path.with_name(path.name.replace("_console.exe", ".exe"))
    require(path.is_file(), f"Editor executable not found: {path}")
    return str(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    args = parser.parse_args()
    engine = str(Path(args.godot).resolve())
    editor = editor_executable(engine)
    report = ROOT / 'reports' / ('mcp-' + uuid.uuid4().hex[:12])
    report.mkdir(parents=True)
    summary = {'status': 'failed', 'report': str(report)}
    si = subprocess.STARTUPINFO()
    si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    si.wShowWindow = 0
    process = None
    try:
        require(subprocess.check_output([engine, '--version'], startupinfo=si).decode().strip()
                == '4.6.2.stable.official.71f334935', 'Expected pinned Godot 4.6.2 standard')
        with tempfile.TemporaryDirectory(prefix='LongeJourney-MCP-') as temp, \
             tempfile.TemporaryDirectory(prefix='LongeJourney-MCP-', dir=os.environ['APPDATA']) as user:
            project = Path(temp) / 'project'
            shutil.copytree(ROOT, project, ignore=shutil.ignore_patterns(
                '.git', '.godot', 'reports', 'backups', '__pycache__', '.gdunit*', '.env', 'config.toml'))
            config = project / 'project.godot'
            text = config.read_text(encoding='utf-8')
            name = Path(user).name
            text = text.replace('config/name="LongeJourney"', f'config/name="{name}"\n'
                                f'config/use_custom_user_dir=true\nconfig/custom_user_dir_name="{name}"')
            require(f'config/custom_user_dir_name="{name}"' in text, 'Failed to isolate user data')
            config.write_text(text, encoding='utf-8')
            with socket.socket() as reserved:
                reserved.bind(('127.0.0.1', 0))
                port = reserved.getsockname()[1]
            (Path(user) / 'godot_dotnet_mcp_settings.json').write_text(json.dumps({
                'port': port, 'host': '127.0.0.1', 'auto_start': True,
                'tool_profile_id': 'intelligence', 'debug_mode': False}), encoding='utf-8')
            # Test-only editor observer: records in-memory debugger events, not disk fallback.
            addon = project / 'addons' / 'mcp_acceptance'
            addon.mkdir()
            (addon / 'plugin.cfg').write_text('[plugin]\nname="MCP acceptance observer"\n'
                'description="Isolated test harness"\nauthor="LongeJourney"\nversion="1"\nscript="plugin.gd"\n')
            (addon / 'plugin.gd').write_text('''@tool
extends EditorPlugin
const Store = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_debug_store.gd")
func _enter_tree() -> void:
    call_deferred("_apply_profile")
func _apply_profile() -> void:
    for sibling in get_parent().get_children():
        if sibling.get_script() != null and sibling.get_script().resource_path == "res://addons/godot_dotnet_mcp/plugin.gd":
            sibling._state.needs_initial_tool_profile_apply = true
            sibling._apply_initial_tool_profile_if_needed()
func _process(_delta: float) -> void:
    if FileAccess.file_exists("res://.mcp-stop"):
        var file = FileAccess.open("res://.mcp-events.json", FileAccess.WRITE)
        file.store_string(JSON.stringify(Store._events))
        file.close()
        set_process(false)
        EditorInterface.save_all_scenes()
        EditorInterface.get_base_control().get_parent().notification.call_deferred(NOTIFICATION_WM_CLOSE_REQUEST)
''', encoding='utf-8')
            text = text.replace(f'"{MCP}"', f'"{MCP}", "res://addons/mcp_acceptance/plugin.cfg"')
            config.write_text(text, encoding='utf-8')
            marker = 'LongeJourney-MCP-Probe-' + uuid.uuid4().hex
            (project / 'mcp_probe.gd').write_text('extends Node\nfunc _ready() -> void:\n'
                f'\tget_node("/root/MCPRuntimeBridge").emit_error("{marker}")\n', encoding='utf-8')
            (project / 'mcp_probe.tscn').write_text('[gd_scene load_steps=2 format=3]\n'
                '[ext_resource type="Script" path="res://mcp_probe.gd" id="1"]\n'
                '[node name="MCPProbe" type="Node"]\nscript = ExtResource("1")\n', encoding='utf-8')
            with (report / 'import.log').open('w', encoding='utf-8') as log:
                result = subprocess.run([engine, '--verbose', '--headless', '--path', str(project), '--editor', '--import'],
                    stdout=log, stderr=subprocess.STDOUT, startupinfo=si, timeout=300)
            require(result.returncode == 0, 'Cold import failed')
            require(not re.search(r'^(SCRIPT ERROR:|ERROR:|WARNING: ObjectDB)',
                (report / 'import.log').read_text(encoding='utf-8'), re.M), 'Cold import logged errors')
            with (report / 'editor.log').open('w', encoding='utf-8') as log:
                process = subprocess.Popen([editor, '--path', str(project), '--editor'],
                    stdout=log, stderr=subprocess.STDOUT, startupinfo=si)
                request_id = 0
                def rpc(method, params=None, notification=False):
                    nonlocal request_id
                    request_id += 1
                    body = {'jsonrpc': '2.0', 'method': method, 'params': params or {}}
                    if not notification:
                        body['id'] = request_id
                    req = urllib.request.Request(f'http://127.0.0.1:{port}/mcp', json.dumps(body).encode(),
                        {'Content-Type': 'application/json', 'Accept': 'application/json, text/event-stream'})
                    with urllib.request.urlopen(req, timeout=30) as response:
                        raw = response.read()
                        result = json.loads(raw) if raw else None
                        (report / f'rpc-{request_id:03}.json').write_text(json.dumps(
                            {'request': body, 'status': response.status, 'response': result},
                            ensure_ascii=False, indent=2), encoding='utf-8')
                        if notification:
                            require(response.status == 202, 'Initialized notification rejected')
                            return None
                        require(response.status == 200 and result.get('id') == request_id
                                and 'error' not in result, f'RPC failed: {result}')
                        return result['result']
                def call(name, arguments=None, expected_success=True):
                    result = rpc('tools/call', {'name': name, 'arguments': arguments or {}})
                    payload = json.loads(result['content'][0]['text'])
                    require(payload.get('success') is expected_success
                            and result.get('isError', False) is not expected_success,
                            f'{name}: unexpected success/error contract: {payload}')
                    return payload.get('data') if expected_success else payload
                try:
                    deadline = time.monotonic() + 90
                    while True:
                        require(process.poll() is None, 'Editor exited before health check')
                        try:
                            with urllib.request.urlopen(f'http://127.0.0.1:{port}/health', timeout=2) as response:
                                health = json.load(response)
                            break
                        except OSError:
                            require(time.monotonic() < deadline, 'Editor health timeout')
                            time.sleep(1)
                    require(health['status'] == 'ok' and health['tool_loader_status']['healthy'], 'Unhealthy server')
                    init = rpc('initialize', {'protocolVersion': '2025-06-18', 'capabilities': {},
                        'clientInfo': {'name': 'LongeJourney-acceptance', 'version': '1'}})
                    require(init['protocolVersion'] == '2025-06-18', 'Wrong protocol')
                    rpc('notifications/initialized', notification=True)
                    tools = rpc('tools/list')['tools']
                    require(len(tools) == 15, 'Unexpected default exposed tool count')
                    state = call('intelligence_project_state')
                    require(state['project_name'] == name, 'Connected to the wrong project')
                    require('res://scenes/mianMenu.tscn' in state['scene_paths'] and
                        'res://scripts/extends Control.gd' in state['script_paths'] and state['resources'] > 0,
                        'Project inventory is incomplete')
                    scene = {'scene': 'res://scenes/mianMenu.tscn'}
                    require(call('intelligence_scene_validate', scene)['valid'], 'False missing dependency')
                    analysis = call('intelligence_scene_analyze', scene)
                    require(analysis['node_count'] == 12 and analysis['script_count'] == 1, 'Invalid scene analysis')
                    call('intelligence_scene_analyze', {'scene': 'res://missing.tscn'}, False)
                    call('intelligence_project_run')
                    time.sleep(5)
                    require(call('intelligence_project_state')['running'], 'Main game did not start')
                    call('intelligence_project_stop')
                    time.sleep(2)
                    require(not call('intelligence_project_state')['running'], 'Main game did not stop')
                    call('intelligence_project_run', {'scene': 'res://mcp_probe.tscn'})
                    time.sleep(4)
                    diagnosis = call('intelligence_runtime_diagnose', {'include_compile_errors': False})
                    require(any(marker in e['message'] for e in diagnosis['runtime_errors']), 'Runtime error not captured')
                    call('intelligence_project_stop')
                    time.sleep(2)
                    diagnosis = call('intelligence_runtime_diagnose', {'include_compile_errors': False})
                    require(any(marker in e['message'] for e in diagnosis['runtime_errors']), 'Stopped session lost errors')
                    summary.update({'functional_checks': 'passed', 'exposed_tools': len(tools), 'scenes': state['scenes'],
                        'scripts': state['scripts'], 'main_scene_nodes': analysis['node_count']})
                finally:
                    (project / '.mcp-stop').touch()
                    try:
                        process.wait(timeout=30)
                    except subprocess.TimeoutExpired:
                        subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], capture_output=True)
                        process.wait(timeout=10)
                        raise RuntimeError('Editor did not exit gracefully')
                summary['editor_exit_code'] = process.returncode
            events = json.loads((project / '.mcp-events.json').read_text(encoding='utf-8'))
            (report / 'live-events.json').write_text(json.dumps(events, ensure_ascii=False, indent=2), encoding='utf-8')
            require(any(e['session_id'] >= 0 and marker in e['payload'].get('message', '') for e in events),
                    'No live debugger event: disk fallback is not accepted as bridge verification')
            summary['live_debugger'] = 'passed'
            require(not re.search(r'^(SCRIPT ERROR:|ERROR:|WARNING: ObjectDB)',
                (report / 'editor.log').read_text(encoding='utf-8'), re.M), 'Editor logged errors')
            require(process.returncode == 0, 'Editor exit failed')
            summary['status'] = 'passed'
    except Exception as exc:
        summary['error'] = str(exc)
        print(f'FAILED: {exc}', flush=True)
    finally:
        (report / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(summary, ensure_ascii=False, indent=2), flush=True)
    return 0 if summary['status'] == 'passed' else 1

if __name__ == '__main__':
    raise SystemExit(main())
