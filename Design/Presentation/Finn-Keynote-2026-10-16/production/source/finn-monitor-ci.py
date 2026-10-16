import json
import subprocess
import time

previous = None
while True:
    try:
        result = subprocess.run(['gh', 'run', 'view', '38875271912', '--repo', 'james8464/finn', '--json', 'status,conclusion,jobs'], capture_output=True, text=True, timeout=40, check=True)
        data = json.loads(result.stdout)
        state = (data['status'], data['conclusion'], tuple((step['name'], step['status'], step['conclusion']) for job in data['jobs'] for step in job['steps']))
        if state != previous:
            print(json.dumps({'status': data['status'], 'conclusion': data['conclusion'], 'steps': [{'name': step['name'], 'status': step['status'], 'conclusion': step['conclusion']} for job in data['jobs'] for step in job['steps'] if step['status'] != 'queued']}), flush=True)
            previous = state
        if data['status'] == 'completed':
            break
    except (subprocess.SubprocessError, ValueError) as error:
        print(type(error).__name__, flush=True)
    time.sleep(45)
