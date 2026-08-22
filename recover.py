
import json, os, re

files_content = {}
log_paths = [
    r"C:\Users\Prince\.gemini\antigravity\brain\75bf4f88-71c0-4146-9ef8-dbfa2815ef2c\.system_generated\logs\transcript_full.jsonl",
    r"C:\Users\Prince\.gemini\antigravity\brain\afc60098-fecb-4cb2-b0dd-077caf91bcf6\.system_generated\logs\transcript_full.jsonl",
    r"C:\Users\Prince\.gemini\antigravity\brain\4d9a36cf-fca4-43a7-9aa5-22f7d46e476d\.system_generated\logs\transcript_full.jsonl",
    r"C:\Users\Prince\.gemini\antigravity\brain\4a43338f-0cde-480d-a488-40fc1a3705af\.system_generated\logs\transcript_full.jsonl"
]

for log_path in log_paths:
    if not os.path.exists(log_path): continue
    with open(log_path, "r", encoding="utf-8") as f:
        for line in f:
            try:
                data = json.loads(line)
                
                # Check write_to_file
                if data.get("type") == "PLANNER_RESPONSE":
                    for tc in data.get("tool_calls", []):
                        if tc["name"] in ["default_api:write_to_file", "write_to_file"]:
                            args = tc["args"]
                            if isinstance(args, str): args = json.loads(args)
                            path = args.get("TargetFile")
                            if path and "c:\\music" in path.lower():
                                files_content[path] = args.get("CodeContent", "")
                
                # Check view_file
                content = data.get("content", "")
                if "File Path: `file:///" in content:
                    match = re.search(r"File Path: `file:///(.*?)`", content)
                    if match:
                        path = match.group(1).replace("/", "\\")
                        if "c:\\music" in path.lower():
                            lines = content.split("\n")
                            in_code = False
                            parsed_lines = []
                            for l in lines:
                                if "The following code has been modified" in l:
                                    in_code = True
                                    continue
                                if "The above content" in l:
                                    break
                                if in_code:
                                    idx = l.find(": ")
                                    if idx != -1 and l[:idx].isdigit():
                                        parsed_lines.append(l[idx+2:])
                                    else:
                                        if "<line_number>" not in l:
                                            parsed_lines.append(l)
                            
                            if len(parsed_lines) > 0:
                                current = files_content.get(path, "")
                                new_content = "\n".join(parsed_lines)
                                if len(new_content) > len(current):
                                    files_content[path] = new_content
            except Exception as e:
                pass

print(f"Recovered {len(files_content)} files")
for path, content in files_content.items():
    print(path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

