"""UI Studio CLI — 封装所有后端 API，供 skill / 脚本 / CI 调用。

用法:
  python ui-studio-cli.py health
  python ui-studio-cli.py workspace init-generate --files design.png [--comment "备注"] [--prompt txt] [--size 1536x1024]
  python ui-studio-cli.py workflow extract --id <ws_id>
  python ui-studio-cli.py workflow layout --id <ws_id>
  python ui-studio-cli.py workspace download-sprites --id <ws_id> --output-dir <目录>

辅助命令:
  python ui-studio-cli.py workspace status --id <ws_id>
  python ui-studio-cli.py workspace list-files --id <ws_id>
  python ui-studio-cli.py workspace download --id <ws_id> --path <相对路径> [-o <输出路径>]
  python ui-studio-cli.py workflow list
  python ui-studio-cli.py workflow extract-status --run-id <run_id>
  python ui-studio-cli.py workflow layout-status --run-id <run_id>

所有子命令输出 JSON 到 stdout，方便 skill 解析。

推荐流程:
  1. workspace init-generate --files <设计图>  (一步完成 init + upload + generate)
  2. workflow extract --id <ws_id>
  3. workflow layout --id <ws_id> (可选)
  4. workspace download-sprites --id <ws_id> --output-dir ./output

注意:
  - init-generate 是推荐入口，一步完成 init、upload、generate 三个操作
  - extract 依赖 init-generate 产出的 001.png
  - download-sprites 批量下载 output/ 下所有最终产物
"""

import argparse
import json
import sys
import os
from pathlib import Path

import httpx

DEFAULT_BASE_URL = os.environ.get("UI_STUDIO_URL", "http://192.168.1.53:8008")
DEFAULT_TIMEOUT = 30
WORKFLOW_TIMEOUT = 600


def _url(path: str) -> str:
    return f"{DEFAULT_BASE_URL}{path}"


def _success(**kwargs) -> dict:
    return {"success": True, **kwargs}


def _error(code: str, message: str, detail: str = None) -> dict:
    result = {"success": False, "error": code, "message": message}
    if detail:
        result["detail"] = detail
    return result


def _progress(**kwargs) -> None:
    print(json.dumps(kwargs, ensure_ascii=False), file=sys.stderr, flush=True)


def _http_result(r: httpx.Response) -> dict:
    if 200 <= r.status_code < 300:
        body = r.json()
        if isinstance(body, dict):
            result = _success(**body)
        else:
            result = _success(data=body)
        result["http_status"] = r.status_code
        if r.status_code == 202 and not result.get("status"):
            result["status"] = "submitted"
        return result
    else:
        body = r.json() if r.headers.get("content-type", "").startswith("application/json") else {"detail": r.text}
        msg = body.get("detail", body.get("error", "Unknown error"))
        detail = None
        if "\n" in msg and len(msg) > 200:
            parts = msg.split("\n", 1)
            msg = parts[0]
            detail = parts[1] if len(parts) > 1 else None
        return _error("api_error", msg, detail)


def _workflow_state(status: str) -> str:
    normalized = str(status or "").upper()
    if normalized == "COMPLETED":
        return "completed"
    if normalized in ("ERROR", "CANCELLED", "CANCELED"):
        return "failed"
    if normalized == "PAUSED":
        return "paused"
    if normalized in ("PENDING", "RUNNING"):
        return "running"
    return "unknown"


def _get(path: str, timeout: int = DEFAULT_TIMEOUT) -> dict:
    try:
        return _http_result(httpx.get(_url(path), timeout=timeout))
    except httpx.HTTPError as exc:
        return _error("network_error", str(exc))


def _post(path: str, json_data: dict = None, files: dict = None, data: dict = None, timeout: int = DEFAULT_TIMEOUT) -> dict:
    try:
        return _http_result(httpx.post(_url(path), json=json_data, files=files, data=data, timeout=timeout))
    except httpx.HTTPError as exc:
        return _error("network_error", str(exc))


def _extract_workflow_result(r: dict) -> dict:
    if not r.get("success"):
        return r
    run_id = r.get("run_id", "")
    status = r.get("status", "")
    outputs = {}
    label_index = {}
    sprite_count = 0
    for step in r.get("step_results", []):
        content = step.get("content", "")
        if isinstance(content, str) and content.startswith("{"):
            try:
                parsed = json.loads(content)
                if "outputs" in parsed:
                    for out in parsed["outputs"]:
                        if out.endswith("sprite-map.json"):
                            outputs["sprite_map"] = out
                        elif "sprite-alpha" in out:
                            outputs["sprite_alpha"] = out
                        elif "sprite-list-preview" in out:
                            outputs["sprite_list_preview"] = out
                        elif out == "001.png" or out.endswith("/001.png"):
                            outputs["sprite_sheet"] = out
                if "label_index" in parsed:
                    label_index = parsed["label_index"]
                if "sprite_count" in parsed:
                    sprite_count = parsed["sprite_count"]
                if "error" in parsed and not outputs:
                    outputs["error"] = parsed["error"]
            except json.JSONDecodeError:
                pass
    session_id = r.get("session_id", "")
    result = _success(run_id=run_id, status=status, outputs=outputs)
    result["state"] = _workflow_state(status)
    if session_id:
        result["session_id"] = session_id
    if sprite_count > 0:
        result["sprite_count"] = sprite_count
    if label_index:
        result["label_index"] = label_index
    return result


def cmd_health(_args):
    return _get("/health")


def cmd_workspace_init(args):
    payload = {}
    if args.comment:
        payload["comment"] = args.comment
    r = _post("/workspace/init", json_data=payload)
    if not r.get("success"):
        return r
    ws_id = r.get("workspace_id")
    if not ws_id:
        return _error("init_failed", "workspace_id not returned")
    uploads = []
    for file_item in args.files:
        file_path = Path(file_item)
        if file_path.exists():
            upload_args = argparse.Namespace(id=ws_id, file=file_item)
            upload_r = cmd_workspace_upload(upload_args)
            if upload_r.get("success"):
                uploads.append({"filename": upload_r.get("filename"), "size": upload_r.get("size")})
    return _success(workspace_id=ws_id, uploads=uploads)


def cmd_workspace_init_generate(args):
    payload = {}
    if args.comment:
        payload["comment"] = args.comment
    r = _post("/workspace/init", json_data=payload)
    if not r.get("success"):
        return r
    ws_id = r.get("workspace_id")
    if not ws_id:
        return _error("init_failed", "workspace_id not returned")
    
    # 立即输出 workspace_id，确保超时杀进程后调用方仍能拿到
    _progress(step="init", workspace_id=ws_id)
    
    uploads = []
    for file_item in args.files:
        file_path = Path(file_item)
        if file_path.exists():
            upload_args = argparse.Namespace(id=ws_id, file=file_item)
            upload_r = cmd_workspace_upload(upload_args)
            if upload_r.get("success"):
                uploads.append({"filename": upload_r.get("filename"), "size": upload_r.get("size")})
    
    if not uploads:
        return _error("no_upload", "No files uploaded, generate requires source images")
    
    _progress(step="upload", workspace_id=ws_id, upload_count=len(uploads))
    
    gen_args = argparse.Namespace(
        id=ws_id,
        prompt=args.prompt or "",
        prompt_file=args.prompt_file or "",
        size=args.size or "1536x1024",
        background=getattr(args, "background", False),
    )
    r_gen = cmd_workflow_generate(gen_args)
    if not r_gen.get("success"):
        return r_gen
    
    result = _success(
        workspace_id=ws_id,
        uploads=uploads,
        generate_run_id=r_gen.get("run_id"),
        generate_session_id=r_gen.get("session_id"),
        generate_status=r_gen.get("status"),
    )
    if getattr(args, "background", False):
        result["hint"] = "generate submitted in background. Use: workflow generate-status --run-id <run_id> --session-id <session_id>"
    return result


def cmd_workspace_status(args):
    r = _get(f"/workspace/{args.id}/status")
    if not r.get("success"):
        return r
    meta = r.get("meta", {})
    products = dict(meta.get("products", {}) or {})
    files_r = _get(f"/workspace/{args.id}/files")
    if files_r.get("success"):
        rename_components = files_r.get("rename_components", [])
        if rename_components:
            products["rename_component_files"] = [
                item for item in rename_components
                if isinstance(item, str) and item.endswith(".png")
            ]
            products.setdefault("rename_components", "output/rename-components")
        if files_r.get("rename_components_manifest"):
            products["rename_components_manifest"] = files_r["rename_components_manifest"]
    result = _success(
        workspace_id=args.id,
        status=meta.get("status"),
        products=products,
        file_count=len(meta.get("source_image_paths", [])),
    )
    for key in ("generate_run_id", "generate_session_id", "generate_status"):
        if meta.get(key):
            result[key] = meta[key]
    return result


def cmd_workspace_upload(args):
    file_path = Path(args.file)
    if not file_path.exists():
        return _error("file_not_found", f"File not found: {args.file}")
    suffix = file_path.suffix.lower()
    content_type = "application/octet-stream"
    if suffix == ".png":
        content_type = "image/png"
    elif suffix in (".jpg", ".jpeg"):
        content_type = "image/jpeg"
    elif suffix == ".webp":
        content_type = "image/webp"
    elif suffix in (".psd", ".psb"):
        content_type = "image/vnd.adobe.photoshop"
    with open(file_path, "rb") as f:
        return _post(f"/workspace/{args.id}/files/upload", files={"file": (file_path.name, f, content_type)}, timeout=120)


def cmd_workspace_list_files(args):
    return _get(f"/workspace/{args.id}/files")


def cmd_workspace_download(args):
    ws_id = args.id
    file_path = args.path
    output = args.output
    
    r = httpx.get(_url(f"/workspace/{ws_id}/files/download?path={file_path}"), timeout=DEFAULT_TIMEOUT, follow_redirects=True)
    
    if r.status_code != 200:
        if r.headers.get("content-type", "").startswith("application/json"):
            body = r.json()
            return _error("download_failed", body.get("detail", "Unknown error"))
        return _error("download_failed", f"HTTP {r.status_code}")
    
    if output:
        out_path = Path(output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "wb") as f:
            f.write(r.content)
        return _success(workspace_id=ws_id, path=file_path, saved_to=str(out_path), size=len(r.content))
    else:
        return _success(workspace_id=ws_id, path=file_path, size=len(r.content), data=r.content[:100].hex() + "..." if len(r.content) > 100 else r.content.hex())


def cmd_workspace_download_sprites(args):
    ws_id = args.id
    output_dir = Path(args.output_dir)
    
    r = _get(f"/workspace/{ws_id}/files")
    if not r.get("success"):
        return r
    
    sprites = r.get("sprites", [])
    sprite_layout_xml = r.get("sprite_layout_xml", "")
    layout_preview = r.get("layout_preview", "")
    sprite_list_preview = r.get("sprite_list_preview", "")
    restore_manifest = r.get("restore_manifest", "")
    frame_layouts = r.get("frame_layouts", [])
    frame_previews = r.get("frame_previews", [])
    
    all_files = list(sprites)
    if sprite_layout_xml:
        all_files.append(sprite_layout_xml)
    if layout_preview:
        all_files.append(layout_preview)
    if sprite_list_preview:
        all_files.append(sprite_list_preview)
    if restore_manifest:
        all_files.append(restore_manifest)
    all_files.extend(frame_layouts)
    all_files.extend(frame_previews)
    
    if not all_files:
        detail_parts = []
        for key in ("stage", "workspace_status", "generated_image", "next_action"):
            value = r.get(key)
            if value:
                detail_parts.append(f"{key}={value}")
        return _error(
            "no_files",
            "No sprite outputs available. Run workflow extract first; run workflow layout if you also need layout XML or restore-manifest.",
            "; ".join(detail_parts) if detail_parts else None,
        )
    
    target_dir = output_dir / ws_id
    target_dir.mkdir(parents=True, exist_ok=True)
    
    downloaded = []
    failed = []
    
    for rel_path in all_files:
        file_r = httpx.get(_url(f"/workspace/{ws_id}/files/download?path={rel_path}"), timeout=DEFAULT_TIMEOUT, follow_redirects=True)
        
        if file_r.status_code != 200:
            failed.append({"path": rel_path, "error": f"HTTP {file_r.status_code}"})
            continue
        
        local_path = target_dir / rel_path
        local_path.parent.mkdir(parents=True, exist_ok=True)
        with open(local_path, "wb") as f:
            f.write(file_r.content)
        downloaded.append({"path": rel_path, "size": len(file_r.content)})
    
    result = _success(
        workspace_id=ws_id,
        output_dir=str(target_dir),
        downloaded_count=len(downloaded),
        failed_count=len(failed),
    )
    if downloaded:
        result["files"] = downloaded
    if failed:
        result["failed"] = failed
    
    return result


def cmd_workflow_list(_args):
    return _get("/workflows")


def cmd_workflow_extract(args):
    payload = {"workspace_id": args.id}
    if getattr(args, "source_format", None) and args.source_format != "auto":
        payload["source_format"] = args.source_format
    if getattr(args, "comment", None):
        payload["comment"] = args.comment
    if getattr(args, "artboard_mode", None) and args.artboard_mode != "auto":
        payload["artboard_mode"] = args.artboard_mode
    form_data = {"message": json.dumps(payload), "stream": "false"}
    if getattr(args, "background", False):
        form_data["background"] = "true"
    r = _post("/workflows/atlas-extract/runs", data=form_data, timeout=WORKFLOW_TIMEOUT)
    return _extract_workflow_result(r)


def cmd_workflow_extract_status(args):
    r = _get(f"/workflows/atlas-extract/runs/{args.run_id}?session_id={args.session_id}")
    return _extract_workflow_result(r)


def cmd_workflow_generate(args):
    msg = {"workspace_id": args.id}
    if args.prompt:
        msg["prompt"] = args.prompt
    if args.prompt_file:
        msg["prompt_file"] = args.prompt_file
    if args.size:
        msg["size"] = args.size
    form_data = {"message": json.dumps(msg), "stream": "false"}
    if getattr(args, "background", False):
        form_data["background"] = "true"
    r = _post("/workflows/sprite-sheet-generate/runs", data=form_data, timeout=WORKFLOW_TIMEOUT)
    result = _extract_workflow_result(r)
    run_id = result.get("run_id")
    session_id = result.get("session_id")
    if run_id and args.id:
        _post(f"/workspace/{args.id}/meta", json_data={"generate_run_id": run_id, "generate_session_id": session_id or ""}, timeout=DEFAULT_TIMEOUT)
    return result


def cmd_workflow_generate_status(args):
    r = _get(f"/workflows/sprite-sheet-generate/runs/{args.run_id}?session_id={args.session_id}")
    return _extract_workflow_result(r)


def cmd_workflow_layout(args):
    msg = {"workspace_id": args.id}
    if args.source_image:
        msg["source_image"] = args.source_image
    if getattr(args, "frame_index", None) is not None and args.frame_index >= 0:
        msg["frame_index"] = args.frame_index
    form_data = {"message": json.dumps(msg), "stream": "false"}
    if getattr(args, "background", False):
        form_data["background"] = "true"
    r = _post("/workflows/layout-reconstruct/runs", data=form_data, timeout=WORKFLOW_TIMEOUT)
    return _layout_workflow_result(r)


def cmd_workflow_layout_status(args):
    r = _get(f"/workflows/layout-reconstruct/runs/{args.run_id}?session_id={args.session_id}")
    return _layout_workflow_result(r)


def cmd_workflow_convert(args):
    payload = {"workspace_id": args.id}
    if getattr(args, "source_format", None) and args.source_format != "auto":
        payload["source_format"] = args.source_format
    form_data = {"message": json.dumps(payload), "stream": "false"}
    if getattr(args, "background", False):
        form_data["background"] = "true"
    r = _post("/workflows/psd-to-figma/runs", data=form_data, timeout=WORKFLOW_TIMEOUT)
    return _figma_workflow_result(r)


def cmd_workflow_convert_status(args):
    r = _get(f"/workflows/psd-to-figma/runs/{args.run_id}?session_id={args.session_id}")
    return _figma_workflow_result(r)


def _figma_workflow_result(r: dict) -> dict:
    if not r.get("success"):
        return r
    run_id = r.get("run_id", "")
    status = r.get("status", "")
    outputs = {}
    for step in r.get("step_results", []):
        content = step.get("content", "")
        if isinstance(content, str) and content.startswith("{"):
            try:
                parsed = json.loads(content)
                if "outputs" in parsed:
                    for out in parsed["outputs"]:
                        if out.endswith("figma-document.json"):
                            outputs["figma_document"] = out
            except json.JSONDecodeError:
                pass
    session_id = r.get("session_id", "")
    result = _success(run_id=run_id, status=status, outputs=outputs)
    result["state"] = _workflow_state(status)
    if session_id:
        result["session_id"] = session_id
    return result


def _layout_workflow_result(r: dict) -> dict:
    if not r.get("success"):
        return r
    run_id = r.get("run_id", "")
    status = r.get("status", "")
    outputs = {}
    for step in r.get("step_results", []):
        content = step.get("content", "")
        if isinstance(content, str) and content.startswith("{"):
            try:
                parsed = json.loads(content)
                if "outputs" in parsed:
                    for out in parsed["outputs"]:
                        if out.endswith("sprite-layout.xml"):
                            outputs["sprite_layout_xml"] = out
                        elif "layout-preview" in out:
                            outputs["layout_preview"] = out
            except json.JSONDecodeError:
                pass
    session_id = r.get("session_id", "")
    result = _success(run_id=run_id, status=status, outputs=outputs)
    result["state"] = _workflow_state(status)
    if session_id:
        result["session_id"] = session_id
    return result


def cmd_workspace_init_extract(args):
    payload = {}
    if args.comment:
        payload["comment"] = args.comment
    r = _post("/workspace/init", json_data=payload)
    if not r.get("success"):
        return r
    ws_id = r.get("workspace_id")
    if not ws_id:
        return _error("init_failed", "workspace_id not returned")

    _progress(step="init", workspace_id=ws_id)

    uploads = []
    for file_item in args.files:
        file_path = Path(file_item)
        if file_path.exists():
            upload_args = argparse.Namespace(id=ws_id, file=file_item)
            upload_r = cmd_workspace_upload(upload_args)
            if upload_r.get("success"):
                uploads.append({"filename": upload_r.get("filename"), "size": upload_r.get("size")})

    if not uploads:
        return _error("no_upload", "No files uploaded, extract requires source files")

    _progress(step="upload", workspace_id=ws_id, upload_count=len(uploads))

    source_format = getattr(args, "source_format", "auto")
    extract_args = argparse.Namespace(
        id=ws_id,
        source_format=source_format,
        comment=getattr(args, "comment", ""),
        artboard_mode=getattr(args, "artboard_mode", "auto"),
        background=getattr(args, "background", False),
    )
    r_extract = cmd_workflow_extract(extract_args)
    if not r_extract.get("success"):
        return r_extract

    result = _success(
        workspace_id=ws_id,
        uploads=uploads,
        extract_run_id=r_extract.get("run_id"),
        extract_session_id=r_extract.get("session_id"),
        extract_status=r_extract.get("status"),
    )
    return result


def _rename_workflow_result(r: dict) -> dict:
    if not r.get("success"):
        return r
    run_id = r.get("run_id", "")
    status = r.get("status", "")
    outputs = {}
    rename_component_files = []
    for step in r.get("step_results", []):
        content = step.get("content", "")
        if isinstance(content, str) and content.startswith("{"):
            try:
                parsed = json.loads(content)
                for rel_path in parsed.get("rename_component_files", []):
                    if rel_path.endswith(".png") and rel_path not in rename_component_files:
                        rename_component_files.append(rel_path)
                if "outputs" in parsed:
                    for out in parsed["outputs"]:
                        if out.endswith("rename-map.json"):
                            outputs["rename_map"] = out
                        elif out.endswith("rename-script.jsx"):
                            outputs["rename_script"] = out
                        elif "rename-preview" in out:
                            outputs["rename_preview"] = out
                        elif out.endswith("rename-components/manifest.json"):
                            outputs["rename_components_manifest"] = out
                        elif out.startswith("output/rename-components/") and out.endswith(".png"):
                            if out not in rename_component_files:
                                rename_component_files.append(out)
                        elif out.rstrip("/").endswith("rename-components"):
                            outputs["rename_components"] = out
            except json.JSONDecodeError:
                pass
    if rename_component_files:
        outputs["rename_component_files"] = rename_component_files
        outputs.setdefault("rename_components", "output/rename-components")
    session_id = r.get("session_id", "")
    result = _success(run_id=run_id, status=status, outputs=outputs)
    result["state"] = _workflow_state(status)
    if session_id:
        result["session_id"] = session_id
    return result


def cmd_workspace_init_rename(args):
    payload = {}
    if args.comment:
        payload["comment"] = args.comment
    r = _post("/workspace/init", json_data=payload)
    if not r.get("success"):
        return r
    ws_id = r.get("workspace_id")
    if not ws_id:
        return _error("init_failed", "workspace_id not returned")

    _progress(step="init", workspace_id=ws_id)

    uploads = []
    for file_item in args.files:
        file_path = Path(file_item)
        if file_path.exists():
            upload_args = argparse.Namespace(id=ws_id, file=file_item)
            upload_r = cmd_workspace_upload(upload_args)
            if upload_r.get("success"):
                uploads.append({"filename": upload_r.get("filename"), "size": upload_r.get("size")})

    if not uploads:
        return _error("no_upload", "No files uploaded, rename requires PSD files")

    _progress(step="upload", workspace_id=ws_id, upload_count=len(uploads))

    rename_args = argparse.Namespace(
        id=ws_id,
        prefix=args.prefix,
        hash_threshold=args.hash_threshold,
        common_names_path=args.common_names_path,
        naming_dict_path=args.naming_dict_path,
        background=args.background,
    )
    r_rename = cmd_workflow_rename(rename_args)
    if not r_rename.get("success"):
        return r_rename

    result = _success(
        workspace_id=ws_id,
        uploads=uploads,
        rename_run_id=r_rename.get("run_id"),
        rename_session_id=r_rename.get("session_id"),
        rename_status=r_rename.get("status"),
    )
    return result


def cmd_workspace_init_rename_prep(args):
    payload = {}
    if args.comment:
        payload["comment"] = args.comment
    r = _post("/workspace/init", json_data=payload)
    if not r.get("success"):
        return r
    ws_id = r.get("workspace_id")
    if not ws_id:
        return _error("init_failed", "workspace_id not returned")

    _progress(step="init", workspace_id=ws_id)

    uploads = []
    for file_item in args.files:
        file_path = Path(file_item)
        if file_path.exists():
            upload_args = argparse.Namespace(id=ws_id, file=file_item)
            upload_r = cmd_workspace_upload(upload_args)
            if upload_r.get("success"):
                uploads.append({"filename": upload_r.get("filename"), "size": upload_r.get("size")})

    if not uploads:
        return _error("no_upload", "No files uploaded, rename-prep requires well-named PSD files for analysis")

    _progress(step="upload", workspace_id=ws_id, upload_count=len(uploads))

    return _success(workspace_id=ws_id, uploads=uploads)


def cmd_workflow_rename(args):
    payload = {
        "workspace_id": args.id,
        "prefix": args.prefix,
        "hash_threshold": args.hash_threshold,
    }
    if args.common_names_path:
        payload["common_names_path"] = args.common_names_path
    if args.naming_dict_path:
        payload["naming_dict_path"] = args.naming_dict_path
    form_data = {"message": json.dumps(payload), "stream": "false"}
    if getattr(args, "background", False):
        form_data["background"] = "true"
    r = _post("/workflows/psd-rename/runs", data=form_data, timeout=WORKFLOW_TIMEOUT)
    return _rename_workflow_result(r)


def cmd_workflow_rename_status(args):
    r = _get(f"/workflows/psd-rename/runs/{args.run_id}?session_id={args.session_id}")
    return _rename_workflow_result(r)


def cmd_workspace_init_convert(args):
    payload = {}
    if args.comment:
        payload["comment"] = args.comment
    r = _post("/workspace/init", json_data=payload)
    if not r.get("success"):
        return r
    ws_id = r.get("workspace_id")
    if not ws_id:
        return _error("init_failed", "workspace_id not returned")

    _progress(step="init", workspace_id=ws_id)

    uploads = []
    for file_item in args.files:
        file_path = Path(file_item)
        if file_path.exists():
            upload_args = argparse.Namespace(id=ws_id, file=file_item)
            upload_r = cmd_workspace_upload(upload_args)
            if upload_r.get("success"):
                uploads.append({"filename": upload_r.get("filename"), "size": upload_r.get("size")})

    if not uploads:
        return _error("no_upload", "No files uploaded, convert requires a PSD file")

    _progress(step="upload", workspace_id=ws_id, upload_count=len(uploads))

    source_format = getattr(args, "source_format", "auto")
    convert_args = argparse.Namespace(id=ws_id, source_format=source_format, background=getattr(args, "background", False))
    r_convert = cmd_workflow_convert(convert_args)
    if not r_convert.get("success"):
        return r_convert

    result = _success(
        workspace_id=ws_id,
        uploads=uploads,
        convert_run_id=r_convert.get("run_id"),
        convert_session_id=r_convert.get("session_id"),
        convert_status=r_convert.get("status"),
    )
    return result


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ui-studio-cli", description="UI Studio API CLI")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="API base URL")

    sub = parser.add_subparsers(dest="command")

    # health
    sub.add_parser("health", help="Health check")

    # workspace
    ws = sub.add_parser("workspace", help="Workspace operations")
    ws_sub = ws.add_subparsers(dest="ws_command")

    ws_init = ws_sub.add_parser("init", help="Create workspace")
    ws_init.add_argument("--comment", default="")
    ws_init.add_argument("--files", nargs="+", required=True, help="image files to upload after init")
    
    ws_init_generate = ws_sub.add_parser("init-generate", help="Create workspace + upload + generate (one-step workflow)")
    ws_init_generate.add_argument("--comment", default="")
    ws_init_generate.add_argument("--files", nargs="+", required=True, help="design image files to upload and generate sprite sheet")
    ws_init_generate.add_argument("--prompt", default="", help="generation prompt text (optional, default template if omitted)")
    ws_init_generate.add_argument("--prompt-file", default="", help="path to prompt file")
    ws_init_generate.add_argument("--size", default="1536x1024", help="image size (default: 1536x1024)")
    ws_init_generate.add_argument("--background", action="store_true", default=False, help="submit generate in background (HTTP 202, return run_id immediately, no blocking wait)")

    ws_init_extract = ws_sub.add_parser("init-extract", help="Create workspace + upload + extract (for PSD files, skips generate)")
    ws_init_extract.add_argument("--comment", default="")
    ws_init_extract.add_argument("--files", nargs="+", required=True, help="source files to upload (PSD or image)")
    ws_init_extract.add_argument("--source-format", default="auto", dest="source_format", choices=["auto", "psd", "image"], help="source format: auto (detect from extension), psd, image (default: auto)")
    ws_init_extract.add_argument("--artboard-mode", default="auto", dest="artboard_mode", choices=["auto", "unified", "independent"], help="artboard mode: auto (LLM decides), unified (sprite-only), independent (per-artboard)")
    ws_init_extract.add_argument("--background", action="store_true", default=False, help="run extract in background")

    ws_init_convert = ws_sub.add_parser("init-convert", help="Create workspace + upload + convert to Figma (PSD→Figma)")
    ws_init_convert.add_argument("--comment", default="")
    ws_init_convert.add_argument("--files", nargs="+", required=True, help="PSD file to upload and convert")
    ws_init_convert.add_argument("--source-format", default="auto", dest="source_format", choices=["auto", "psd"], help="source format: auto (detect) or psd (default: auto)")
    ws_init_convert.add_argument("--background", action="store_true", default=False, help="run convert in background")

    ws_init_rename = ws_sub.add_parser("init-rename", help="Create workspace + upload PSD + run rename workflow")
    ws_init_rename.add_argument("--comment", default="")
    ws_init_rename.add_argument("--files", nargs="+", required=True, help="PSD files to upload and rename")
    ws_init_rename.add_argument("--prefix", required=True, help="rename prefix (e.g., 'ui_login_')")
    ws_init_rename.add_argument("--hash-threshold", type=int, default=10, dest="hash_threshold", help="perceptual hash threshold for grouping (default: 10)")
    ws_init_rename.add_argument("--common-names-path", default="", dest="common_names_path", help="path to common-names.json in workspace (optional)")
    ws_init_rename.add_argument("--naming-dict-path", default="", dest="naming_dict_path", help="path to naming-dictionary.json in workspace (optional)")
    ws_init_rename.add_argument("--background", action="store_true", default=False, help="run rename in background")

    ws_init_rename_prep = ws_sub.add_parser("init-rename-prep", help="Create workspace + upload files (preparation phase for naming analysis)")
    ws_init_rename_prep.add_argument("--comment", default="")
    ws_init_rename_prep.add_argument("--files", nargs="+", required=True, help="well-named PSD files for naming pattern analysis")

    ws_status = ws_sub.add_parser("status", help="Get workspace status")
    ws_status.add_argument("--id", required=True, dest="id")

    ws_list = ws_sub.add_parser("list-files", help="List workspace files")
    ws_list.add_argument("--id", required=True, dest="id")
    
    ws_download = ws_sub.add_parser("download", help="Download a single file from workspace")
    ws_download.add_argument("--id", required=True, dest="id", help="workspace_id")
    ws_download.add_argument("--path", required=True, dest="path", help="file path relative to workspace root (e.g., 'output/sprites/sprite-atlas.json')")
    ws_download.add_argument("--output", "-o", default="", dest="output", help="output file path (optional, prints hex preview if omitted)")
    
    ws_download_sprites = ws_sub.add_parser("download-sprites", help="Download all sprites from output/sprites directory")
    ws_download_sprites.add_argument("--id", required=True, dest="id", help="workspace_id")
    ws_download_sprites.add_argument("--output-dir", "-o", required=True, dest="output_dir", help="output directory (workspace_id will be created as subdirectory)")

    # workflow
    wf = sub.add_parser("workflow", help="Workflow operations")
    wf_sub = wf.add_subparsers(dest="wf_command")

    wf_sub.add_parser("list", help="List all workflows")

    wf_extract = wf_sub.add_parser("extract", help="Run atlas-extract workflow")
    wf_extract.add_argument("--id", required=True, dest="id", help="workspace_id")
    wf_extract.add_argument("--source-format", default="auto", dest="source_format", choices=["auto", "psd", "image"], help="source format: auto (detect), psd, image (default: auto)")
    wf_extract.add_argument("--comment", default="", help="user intent comment (used by LLM for artboard mode decision)")
    wf_extract.add_argument("--artboard-mode", default="auto", dest="artboard_mode", choices=["auto", "unified", "independent"], help="artboard extraction mode: auto (LLM decides), unified (sprite-only, no atlas), independent (per-artboard full workflow)")
    wf_extract.add_argument("--background", action="store_true", default=False, help="run in background (HTTP 202, return run_id immediately)")

    wf_extract_st = wf_sub.add_parser("extract-status", help="Check extract workflow status")
    wf_extract_st.add_argument("--run-id", required=True)
    wf_extract_st.add_argument("--session-id", required=True, dest="session_id", help="session_id returned when the run was created")

    wf_gen = wf_sub.add_parser("generate", help="Run sprite-sheet-generate workflow (gpt-image-2)")
    wf_gen.add_argument("--id", required=True, dest="id", help="workspace_id")
    wf_gen.add_argument("--prompt", default="", help="generation prompt text (optional, default template if omitted)")
    wf_gen.add_argument("--prompt-file", default="", help="path to prompt file")
    wf_gen.add_argument("--size", default="1536x1024", help="image size (default: 1536x1024)")
    wf_gen.add_argument("--background", action="store_true", default=False, help="run in background (HTTP 202, return run_id immediately)")

    wf_gen_st = wf_sub.add_parser("generate-status", help="Check generate workflow status")
    wf_gen_st.add_argument("--run-id", required=True)
    wf_gen_st.add_argument("--session-id", required=True, dest="session_id", help="session_id returned when the run was created")
    
    wf_layout = wf_sub.add_parser("layout", help="Run layout-reconstruct workflow")
    wf_layout.add_argument("--id", required=True, dest="id", help="workspace_id")
    wf_layout.add_argument("--source-image", default="", help="source design image filename (optional, auto-detected from upload)")
    wf_layout.add_argument("--frame-index", type=int, default=-1, dest="frame_index", help="only layout a specific frame index (default: all frames)")
    wf_layout.add_argument("--background", action="store_true", default=False, help="run in background (HTTP 202, return run_id immediately)")
    
    wf_layout_st = wf_sub.add_parser("layout-status", help="Check layout workflow status")
    wf_layout_st.add_argument("--run-id", required=True)
    wf_layout_st.add_argument("--session-id", required=True, dest="session_id", help="session_id returned when the run was created")

    wf_convert = wf_sub.add_parser("convert", help="Run PSD-to-Figma conversion workflow")
    wf_convert.add_argument("--id", required=True, dest="id", help="workspace_id")
    wf_convert.add_argument("--source-format", default="auto", dest="source_format", choices=["auto", "psd"], help="source format (default: auto)")
    wf_convert.add_argument("--background", action="store_true", default=False, help="run in background (HTTP 202, return run_id immediately)")

    wf_convert_st = wf_sub.add_parser("convert-status", help="Check PSD-to-Figma conversion status")
    wf_convert_st.add_argument("--run-id", required=True)
    wf_convert_st.add_argument("--session-id", required=True, dest="session_id", help="session_id returned when the run was created")

    wf_rename = wf_sub.add_parser("rename", help="Run psd-rename workflow")
    wf_rename.add_argument("--id", required=True, dest="id", help="workspace_id")
    wf_rename.add_argument("--prefix", required=True, help="rename prefix (e.g., 'ui_login_')")
    wf_rename.add_argument("--hash-threshold", type=int, default=10, dest="hash_threshold", help="perceptual hash threshold for grouping (default: 10)")
    wf_rename.add_argument("--common-names-path", default="", dest="common_names_path", help="path to common-names.json in workspace (optional)")
    wf_rename.add_argument("--naming-dict-path", default="", dest="naming_dict_path", help="path to naming-dictionary.json in workspace (optional)")
    wf_rename.add_argument("--background", action="store_true", default=False, help="run in background (HTTP 202, return run_id immediately)")

    wf_rename_st = wf_sub.add_parser("rename-status", help="Check psd-rename workflow status")
    wf_rename_st.add_argument("--run-id", required=True)
    wf_rename_st.add_argument("--session-id", required=True, dest="session_id", help="session_id returned when the run was created")

    return parser


DISPATCH = {
    "health": cmd_health,
    "workspace": {
        "init": cmd_workspace_init,
        "init-generate": cmd_workspace_init_generate,
        "init-extract": cmd_workspace_init_extract,
        "init-convert": cmd_workspace_init_convert,
        "init-rename": cmd_workspace_init_rename,
        "init-rename-prep": cmd_workspace_init_rename_prep,
        "status": cmd_workspace_status,
        "list-files": cmd_workspace_list_files,
        "download": cmd_workspace_download,
        "download-sprites": cmd_workspace_download_sprites,
    },
    "workflow": {
        "list": cmd_workflow_list,
        "extract": cmd_workflow_extract,
        "extract-status": cmd_workflow_extract_status,
        "generate": cmd_workflow_generate,
        "generate-status": cmd_workflow_generate_status,
        "layout": cmd_workflow_layout,
        "layout-status": cmd_workflow_layout_status,
        "convert": cmd_workflow_convert,
        "convert-status": cmd_workflow_convert_status,
        "rename": cmd_workflow_rename,
        "rename-status": cmd_workflow_rename_status,
    },
}


def main():
    parser = build_parser()
    args = parser.parse_args()

    if args.base_url:
        global DEFAULT_BASE_URL
        DEFAULT_BASE_URL = args.base_url

    cmd = args.command
    if not cmd:
        parser.print_help()
        sys.exit(1)

    if cmd in ("workspace", "workflow"):
        sub_cmd = getattr(args, f"{cmd}_command", None) or getattr(args, {"workspace": "ws_command", "workflow": "wf_command"}[cmd])
        handler = DISPATCH[cmd].get(sub_cmd)
        if not handler:
            parser.parse_args([cmd, "--help"])
            sys.exit(1)
    else:
        handler = DISPATCH.get(cmd)
        if not handler:
            parser.print_help()
            sys.exit(1)

    result = handler(args)
    if result is not None:
        print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
