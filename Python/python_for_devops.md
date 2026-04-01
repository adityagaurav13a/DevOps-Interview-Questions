# Python for DevOps — Complete Deep Dive
## Fundamentals + boto3 + REST API + Pytest + CI/CD + Real Scripts
### Theory → Code → Interview Questions

---

## README — How to Use This Document

**Total sections:** 10
**Your strongest sections (real experience):** boto3 automation, health check scripts, Pytest, CI/CD
**Target level:** Mid-level to Senior DevOps Engineer interviews

### Priority topics to nail:
| Section | Topic | Why it matters |
|---|---|---|
| Part 3 | boto3 EC2/S3/Lambda | Directly on your resume |
| Part 6 | Pytest fixtures + mocking | SDET + DevOps crossover |
| Part 10 | Real scripts (health check, bug repro) | You claim this on resume |

### Power phrases:
- *"I wrote Python automation tools that reduced incident triage from 30 to 5 minutes"*
- *"I use boto3 for infrastructure automation — EC2 lifecycle, S3 ops, Lambda invocation"*
- *"I always structure scripts with proper logging, error handling, and retry logic"*
- *"My health check script polls multiple endpoints and reports to CloudWatch"*

---

## PART 1 — PYTHON FUNDAMENTALS FOR DEVOPS

### OOP in DevOps Context

```python
# Classes used for: config management, API clients, resource managers

class AWSResourceManager:
    """Manages AWS resources with retry and logging."""
    
    def __init__(self, region: str, max_retries: int = 3):
        self.region = region
        self.max_retries = max_retries
        self._session = None  # lazy initialisation
    
    @property
    def session(self):
        """Lazy property — creates session on first access."""
        if self._session is None:
            import boto3
            self._session = boto3.Session(region_name=self.region)
        return self._session
    
    @classmethod
    def from_env(cls) -> 'AWSResourceManager':
        """Factory method — create from environment variables."""
        import os
        return cls(
            region=os.environ.get('AWS_REGION', 'ap-south-1'),
            max_retries=int(os.environ.get('MAX_RETRIES', '3'))
        )
    
    @staticmethod
    def is_valid_region(region: str) -> bool:
        """Static method — no instance needed."""
        valid_regions = ['ap-south-1', 'us-east-1', 'us-west-2']
        return region in valid_regions
    
    def __repr__(self):
        return f"AWSResourceManager(region={self.region})"
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Cleanup on exit — context manager protocol."""
        self._session = None
        return False  # don't suppress exceptions


# Usage
with AWSResourceManager.from_env() as manager:
    print(manager.session)
```

### Decorators for DevOps

```python
import functools
import time
import logging

# Decorator 1: Retry with exponential backoff
def retry(max_attempts=3, delay=1, backoff=2, exceptions=(Exception,)):
    """Retry decorator with exponential backoff."""
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            attempts = 0
            wait = delay
            while attempts < max_attempts:
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    attempts += 1
                    if attempts == max_attempts:
                        raise
                    logging.warning(
                        f"Attempt {attempts} failed: {e}. "
                        f"Retrying in {wait}s..."
                    )
                    time.sleep(wait)
                    wait *= backoff
        return wrapper
    return decorator

# Decorator 2: Timing
def timer(func):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        result = func(*args, **kwargs)
        elapsed = time.perf_counter() - start
        logging.info(f"{func.__name__} completed in {elapsed:.3f}s")
        return result
    return wrapper

# Decorator 3: Circuit breaker
class CircuitBreaker:
    def __init__(self, failure_threshold=5, recovery_timeout=60):
        self.failure_count = 0
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.last_failure_time = None
        self.state = 'CLOSED'  # CLOSED, OPEN, HALF-OPEN
    
    def __call__(self, func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            if self.state == 'OPEN':
                if time.time() - self.last_failure_time > self.recovery_timeout:
                    self.state = 'HALF-OPEN'
                else:
                    raise Exception(f"Circuit breaker OPEN for {func.__name__}")
            try:
                result = func(*args, **kwargs)
                if self.state == 'HALF-OPEN':
                    self.state = 'CLOSED'
                    self.failure_count = 0
                return result
            except Exception as e:
                self.failure_count += 1
                self.last_failure_time = time.time()
                if self.failure_count >= self.failure_threshold:
                    self.state = 'OPEN'
                raise
        return wrapper

# Usage
@retry(max_attempts=3, delay=2, backoff=2, exceptions=(ConnectionError,))
@timer
def deploy_to_aws():
    # deployment code
    pass
```

### Context Managers

```python
import contextlib
import tempfile
import os

# Custom context manager — class based
class TempDirectory:
    """Creates temp directory, cleans up on exit."""
    def __init__(self, prefix='devops_'):
        self.prefix = prefix
        self.path = None
    
    def __enter__(self):
        self.path = tempfile.mkdtemp(prefix=self.prefix)
        return self.path
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        import shutil
        shutil.rmtree(self.path, ignore_errors=True)
        return False

# Generator-based context manager
@contextlib.contextmanager
def managed_aws_client(service, region='ap-south-1'):
    """Ensures proper cleanup of AWS client resources."""
    import boto3
    client = boto3.client(service, region_name=region)
    try:
        yield client
    except Exception as e:
        logging.error(f"Error with {service} client: {e}")
        raise
    finally:
        # boto3 clients don't need explicit close
        # but pattern useful for DB connections, file handles
        logging.info(f"Releasing {service} client")

# Usage
with TempDirectory() as tmpdir:
    # work with tmpdir
    config_path = os.path.join(tmpdir, 'config.yaml')
    # auto-cleaned when block exits

with managed_aws_client('s3') as s3:
    s3.list_buckets()
```

### Generators and Iterators

```python
# Generators for memory-efficient processing of large datasets

def read_cloudwatch_logs(log_group, log_stream, client):
    """Generator — yields log events one at a time."""
    kwargs = {
        'logGroupName': log_group,
        'logStreamName': log_stream
    }
    while True:
        response = client.get_log_events(**kwargs)
        events = response.get('events', [])
        if not events:
            break
        for event in events:
            yield event['message']
        
        next_token = response.get('nextForwardToken')
        if not next_token or next_token == kwargs.get('nextToken'):
            break
        kwargs['nextToken'] = next_token

# vs loading ALL logs into memory (bad for large logs)
def read_all_logs_bad(log_group, log_stream, client):
    all_logs = []  # might be gigabytes!
    # ... same code but append to list
    return all_logs

# Usage — processes one event at a time regardless of log size
for log_line in read_cloudwatch_logs('/app/prod', 'api-server', client):
    if 'ERROR' in log_line:
        print(log_line)

# Generator for batching
def batch(iterable, size=100):
    """Split iterable into chunks of size N."""
    batch_data = []
    for item in iterable:
        batch_data.append(item)
        if len(batch_data) == size:
            yield batch_data
            batch_data = []
    if batch_data:
        yield batch_data

# Process S3 objects in batches
objects = s3.list_objects_v2(Bucket='my-bucket')['Contents']
for chunk in batch(objects, size=50):
    process_batch(chunk)
```

### Type Hints (important for team codebases)

```python
from typing import Optional, List, Dict, Any, Tuple, Union
from dataclasses import dataclass

@dataclass
class DeploymentConfig:
    """Typed config — better than raw dicts."""
    service: str
    version: str
    region: str
    replicas: int = 3
    env_vars: Dict[str, str] = None
    
    def __post_init__(self):
        if self.env_vars is None:
            self.env_vars = {}

def deploy_service(
    config: DeploymentConfig,
    dry_run: bool = False
) -> Tuple[bool, str]:
    """
    Deploy a service.
    
    Returns: (success, message)
    """
    if dry_run:
        return True, f"DRY RUN: would deploy {config.service} v{config.version}"
    
    try:
        # deployment logic
        return True, "Deployment successful"
    except Exception as e:
        return False, f"Deployment failed: {e}"
```

---

## PART 2 — FILE + OS AUTOMATION

### os and pathlib

```python
import os
import pathlib
import shutil

# pathlib — modern, cross-platform (prefer over os.path)
base_dir = pathlib.Path('/app/configs')

# Create directories
(base_dir / 'environments' / 'prod').mkdir(parents=True, exist_ok=True)

# Find files
yaml_files = list(base_dir.glob('**/*.yaml'))  # recursive
env_files = list(base_dir.glob('*.env'))        # current dir only

# Read/write
config_file = base_dir / 'config.yaml'
content = config_file.read_text(encoding='utf-8')
config_file.write_text(new_content, encoding='utf-8')

# File operations
source = pathlib.Path('/tmp/artifact.zip')
dest = pathlib.Path('/app/releases/v1.2.3.zip')

# Copy
shutil.copy2(source, dest)          # copy with metadata
shutil.copytree(source_dir, dest_dir, dirs_exist_ok=True)

# Move
shutil.move(str(source), str(dest))

# Delete
dest.unlink()                        # delete file
shutil.rmtree('/tmp/old-release')    # delete directory tree

# Check existence
if config_file.exists() and config_file.is_file():
    # process
    pass

# File info
stat = config_file.stat()
size_mb = stat.st_size / (1024 * 1024)
modified = stat.st_mtime

# Environment cleanup script
def cleanup_old_artifacts(artifacts_dir: str, keep_last: int = 5):
    """Keep only the N most recent release artifacts."""
    artifacts = pathlib.Path(artifacts_dir)
    all_artifacts = sorted(
        artifacts.glob('*.zip'),
        key=lambda p: p.stat().st_mtime,
        reverse=True  # newest first
    )
    
    to_delete = all_artifacts[keep_last:]
    for artifact in to_delete:
        artifact.unlink()
        print(f"Deleted: {artifact}")
    
    print(f"Kept {min(keep_last, len(all_artifacts))} artifacts")
```

### subprocess — Running Shell Commands

```python
import subprocess
import shlex

# Basic: run command, capture output
def run_command(
    cmd: str | list,
    check: bool = True,
    capture_output: bool = True,
    timeout: int = 60
) -> subprocess.CompletedProcess:
    """
    Safe wrapper around subprocess.run.
    
    Args:
        cmd: command string or list of args
        check: raise CalledProcessError if non-zero exit
        capture_output: capture stdout/stderr
        timeout: seconds before TimeoutExpired
    """
    if isinstance(cmd, str):
        cmd = shlex.split(cmd)  # safe split (handles quotes)
    
    return subprocess.run(
        cmd,
        check=check,
        capture_output=capture_output,
        text=True,          # return str not bytes
        timeout=timeout
    )

# Usage
result = run_command("kubectl get pods -n production")
print(result.stdout)
print(result.returncode)

# Run and check output
result = run_command("docker ps --format '{{.Names}}'")
running_containers = result.stdout.strip().split('\n')

# Streaming output (for long-running commands)
def run_streaming(cmd: list):
    """Stream output as command runs — good for deployments."""
    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1  # line buffered
    )
    
    for line in process.stdout:
        print(line, end='')  # stream to console
    
    process.wait()
    return process.returncode

# Pipeline: cmd1 | cmd2
def pipeline(cmd1: list, cmd2: list) -> str:
    """Run two commands in a pipeline."""
    p1 = subprocess.Popen(cmd1, stdout=subprocess.PIPE)
    p2 = subprocess.Popen(cmd2, stdin=p1.stdout, stdout=subprocess.PIPE, text=True)
    p1.stdout.close()
    output, _ = p2.communicate()
    return output

# Example: docker ps | grep running
output = pipeline(
    ['docker', 'ps'],
    ['grep', 'running']
)

# SECURITY: never use shell=True with user input
# SAFE:
run_command(['kubectl', 'delete', 'pod', pod_name])

# DANGEROUS — shell injection:
os.system(f"kubectl delete pod {pod_name}")  # if pod_name = "x; rm -rf /"
```

---

## PART 3 — AWS AUTOMATION WITH BOTO3

### EC2 Automation

```python
import boto3
import time
from typing import Optional

class EC2Manager:
    def __init__(self, region='ap-south-1'):
        self.ec2 = boto3.client('ec2', region_name=region)
        self.resource = boto3.resource('ec2', region_name=region)
    
    def launch_instance(
        self,
        ami_id: str,
        instance_type: str,
        key_name: str,
        security_group_ids: list,
        subnet_id: str,
        name: str,
        user_data: str = '',
        tags: dict = None
    ) -> str:
        """Launch EC2 instance and return instance ID."""
        tag_specs = [
            {
                'ResourceType': 'instance',
                'Tags': [
                    {'Key': 'Name', 'Value': name},
                    {'Key': 'ManagedBy', 'Value': 'Python'},
                    *(
                        [{'Key': k, 'Value': v} for k, v in tags.items()]
                        if tags else []
                    )
                ]
            }
        ]
        
        response = self.ec2.run_instances(
            ImageId=ami_id,
            InstanceType=instance_type,
            KeyName=key_name,
            SecurityGroupIds=security_group_ids,
            SubnetId=subnet_id,
            MinCount=1,
            MaxCount=1,
            UserData=user_data,
            TagSpecifications=tag_specs,
            IamInstanceProfile={'Name': 'my-ec2-profile'}
        )
        
        instance_id = response['Instances'][0]['InstanceId']
        print(f"Launched: {instance_id}")
        return instance_id
    
    def wait_for_running(self, instance_id: str, timeout: int = 300):
        """Wait until instance is running."""
        waiter = self.ec2.get_waiter('instance_running')
        waiter.wait(
            InstanceIds=[instance_id],
            WaiterConfig={'Delay': 10, 'MaxAttempts': timeout // 10}
        )
        print(f"Instance {instance_id} is running")
    
    def get_instances_by_tag(self, key: str, value: str) -> list:
        """Find instances by tag."""
        response = self.ec2.describe_instances(
            Filters=[
                {'Name': f'tag:{key}', 'Values': [value]},
                {'Name': 'instance-state-name', 'Values': ['running', 'stopped']}
            ]
        )
        instances = []
        for reservation in response['Reservations']:
            instances.extend(reservation['Instances'])
        return instances
    
    def stop_instances_by_tag(self, key: str, value: str):
        """Stop all instances with a specific tag."""
        instances = self.get_instances_by_tag(key, value)
        instance_ids = [i['InstanceId'] for i in instances]
        
        if instance_ids:
            self.ec2.stop_instances(InstanceIds=instance_ids)
            print(f"Stopping: {instance_ids}")
        else:
            print("No instances found")
    
    def get_instance_health(self, instance_id: str) -> dict:
        """Get instance status checks."""
        response = self.ec2.describe_instance_status(
            InstanceIds=[instance_id]
        )
        if response['InstanceStatuses']:
            status = response['InstanceStatuses'][0]
            return {
                'instance_id': instance_id,
                'state': status['InstanceState']['Name'],
                'system_check': status['SystemStatus']['Status'],
                'instance_check': status['InstanceStatus']['Status']
            }
        return {'instance_id': instance_id, 'state': 'unknown'}
```

### S3 Automation

```python
import boto3
import os
import hashlib
from pathlib import Path

class S3Manager:
    def __init__(self, bucket: str, region='ap-south-1'):
        self.bucket = bucket
        self.s3 = boto3.client('s3', region_name=region)
    
    def upload_file(
        self,
        local_path: str,
        s3_key: str,
        metadata: dict = None,
        content_type: str = None
    ) -> str:
        """Upload file to S3 with optional metadata."""
        extra_args = {}
        if metadata:
            extra_args['Metadata'] = metadata
        if content_type:
            extra_args['ContentType'] = content_type
        
        self.s3.upload_file(
            local_path,
            self.bucket,
            s3_key,
            ExtraArgs=extra_args
        )
        return f"s3://{self.bucket}/{s3_key}"
    
    def upload_directory(self, local_dir: str, s3_prefix: str):
        """Upload entire directory to S3."""
        local_path = Path(local_dir)
        for file_path in local_path.rglob('*'):
            if file_path.is_file():
                relative = file_path.relative_to(local_path)
                s3_key = f"{s3_prefix}/{relative}"
                self.upload_file(str(file_path), s3_key)
                print(f"Uploaded: {relative} → {s3_key}")
    
    def download_file(self, s3_key: str, local_path: str):
        """Download file from S3."""
        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        self.s3.download_file(self.bucket, s3_key, local_path)
    
    def list_objects(self, prefix: str = '', suffix: str = '') -> list:
        """List objects with optional prefix/suffix filter."""
        paginator = self.s3.get_paginator('list_objects_v2')
        objects = []
        
        for page in paginator.paginate(Bucket=self.bucket, Prefix=prefix):
            for obj in page.get('Contents', []):
                if not suffix or obj['Key'].endswith(suffix):
                    objects.append(obj)
        
        return objects
    
    def delete_old_artifacts(self, prefix: str, keep_last: int = 5):
        """Delete old artifacts, keep most recent N."""
        objects = self.list_objects(prefix=prefix)
        objects.sort(key=lambda x: x['LastModified'], reverse=True)
        
        to_delete = objects[keep_last:]
        if to_delete:
            self.s3.delete_objects(
                Bucket=self.bucket,
                Delete={
                    'Objects': [{'Key': obj['Key']} for obj in to_delete]
                }
            )
            print(f"Deleted {len(to_delete)} old artifacts")
    
    def generate_presigned_url(
        self,
        s3_key: str,
        expiry_seconds: int = 3600,
        operation: str = 'get_object'
    ) -> str:
        """Generate presigned URL for temporary access."""
        return self.s3.generate_presigned_url(
            operation,
            Params={'Bucket': self.bucket, 'Key': s3_key},
            ExpiresIn=expiry_seconds
        )
    
    def sync_to_s3(self, local_dir: str, s3_prefix: str):
        """
        Sync local directory to S3 (only upload changed files).
        Like aws s3 sync but in Python.
        """
        local_path = Path(local_dir)
        
        # Get existing S3 objects with their ETags (MD5 of content)
        existing = {
            obj['Key']: obj['ETag'].strip('"')
            for obj in self.list_objects(prefix=s3_prefix)
        }
        
        for file_path in local_path.rglob('*'):
            if not file_path.is_file():
                continue
            
            relative = file_path.relative_to(local_path)
            s3_key = f"{s3_prefix}/{relative}"
            
            # Check if file has changed (compare MD5)
            local_md5 = hashlib.md5(file_path.read_bytes()).hexdigest()
            
            if existing.get(s3_key) != local_md5:
                self.upload_file(str(file_path), s3_key)
                print(f"Synced: {relative}")
            else:
                print(f"Unchanged: {relative}")
```

### Lambda + CloudWatch Automation

```python
import boto3
import json
import base64
from datetime import datetime, timedelta

class LambdaManager:
    def __init__(self, region='ap-south-1'):
        self.lambda_client = boto3.client('lambda', region_name=region)
    
    def invoke(
        self,
        function_name: str,
        payload: dict,
        invocation_type: str = 'RequestResponse'
    ) -> dict:
        """Invoke Lambda function."""
        response = self.lambda_client.invoke(
            FunctionName=function_name,
            InvocationType=invocation_type,  # RequestResponse or Event
            Payload=json.dumps(payload)
        )
        
        if invocation_type == 'RequestResponse':
            result = json.loads(response['Payload'].read())
            status_code = response['StatusCode']
            
            if status_code != 200:
                raise Exception(f"Lambda failed: {result}")
            
            return result
        
        return {'status': 'async invocation sent'}
    
    def update_function_code(self, function_name: str, zip_path: str):
        """Update Lambda function code from zip file."""
        with open(zip_path, 'rb') as f:
            zip_bytes = f.read()
        
        response = self.lambda_client.update_function_code(
            FunctionName=function_name,
            ZipFile=zip_bytes
        )
        
        # Wait for update to complete
        waiter = self.lambda_client.get_waiter('function_updated')
        waiter.wait(FunctionName=function_name)
        
        return response['FunctionArn']
    
    def get_recent_errors(self, function_name: str, hours: int = 1) -> list:
        """Get Lambda errors from CloudWatch in the last N hours."""
        logs_client = boto3.client('logs')
        
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=hours)
        
        log_group = f"/aws/lambda/{function_name}"
        
        response = logs_client.filter_log_events(
            logGroupName=log_group,
            startTime=int(start_time.timestamp() * 1000),
            endTime=int(end_time.timestamp() * 1000),
            filterPattern='ERROR'
        )
        
        return [event['message'] for event in response['events']]


class CloudWatchManager:
    def __init__(self, region='ap-south-1'):
        self.cw = boto3.client('cloudwatch', region_name=region)
    
    def put_metric(
        self,
        namespace: str,
        metric_name: str,
        value: float,
        unit: str = 'Count',
        dimensions: dict = None
    ):
        """Push custom metric to CloudWatch."""
        metric_data = {
            'MetricName': metric_name,
            'Value': value,
            'Unit': unit,
            'Timestamp': datetime.utcnow()
        }
        
        if dimensions:
            metric_data['Dimensions'] = [
                {'Name': k, 'Value': v}
                for k, v in dimensions.items()
            ]
        
        self.cw.put_metric_data(
            Namespace=namespace,
            MetricData=[metric_data]
        )
    
    def create_alarm(
        self,
        alarm_name: str,
        metric_name: str,
        namespace: str,
        threshold: float,
        comparison: str = 'GreaterThanThreshold',
        evaluation_periods: int = 2,
        sns_topic_arn: str = None
    ):
        """Create CloudWatch alarm."""
        kwargs = {
            'AlarmName': alarm_name,
            'MetricName': metric_name,
            'Namespace': namespace,
            'Threshold': threshold,
            'ComparisonOperator': comparison,
            'EvaluationPeriods': evaluation_periods,
            'Period': 300,  # 5 minutes
            'Statistic': 'Average',
            'TreatMissingData': 'notBreaching'
        }
        
        if sns_topic_arn:
            kwargs['AlarmActions'] = [sns_topic_arn]
        
        self.cw.put_metric_alarm(**kwargs)
        print(f"Created alarm: {alarm_name}")
```

---

## PART 4 — REST API CALLS

```python
import requests
import time
import logging
from typing import Optional

class APIClient:
    """Robust HTTP client with retry, auth, and error handling."""
    
    def __init__(
        self,
        base_url: str,
        api_key: str = None,
        timeout: int = 30,
        max_retries: int = 3
    ):
        self.base_url = base_url.rstrip('/')
        self.timeout = timeout
        self.max_retries = max_retries
        
        self.session = requests.Session()
        
        # Set default headers
        self.session.headers.update({
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'DevOps-Script/1.0'
        })
        
        if api_key:
            self.session.headers['Authorization'] = f'Bearer {api_key}'
    
    def _request(
        self,
        method: str,
        endpoint: str,
        **kwargs
    ) -> requests.Response:
        """Make HTTP request with retry logic."""
        url = f"{self.base_url}/{endpoint.lstrip('/')}"
        
        for attempt in range(self.max_retries):
            try:
                response = self.session.request(
                    method,
                    url,
                    timeout=self.timeout,
                    **kwargs
                )
                
                # Retry on server errors (5xx) and rate limiting (429)
                if response.status_code in (429, 502, 503, 504):
                    if attempt < self.max_retries - 1:
                        wait = 2 ** attempt
                        logging.warning(
                            f"HTTP {response.status_code} on {url}. "
                            f"Retrying in {wait}s..."
                        )
                        time.sleep(wait)
                        continue
                
                response.raise_for_status()  # raise for 4xx/5xx
                return response
                
            except requests.ConnectionError as e:
                if attempt < self.max_retries - 1:
                    time.sleep(2 ** attempt)
                    continue
                raise
            except requests.Timeout:
                logging.error(f"Timeout on {url} after {self.timeout}s")
                raise
        
        raise Exception(f"All {self.max_retries} attempts failed for {url}")
    
    def get(self, endpoint: str, params: dict = None) -> dict:
        return self._request('GET', endpoint, params=params).json()
    
    def post(self, endpoint: str, data: dict) -> dict:
        return self._request('POST', endpoint, json=data).json()
    
    def put(self, endpoint: str, data: dict) -> dict:
        return self._request('PUT', endpoint, json=data).json()
    
    def delete(self, endpoint: str) -> bool:
        self._request('DELETE', endpoint)
        return True
    
    def health_check(self) -> bool:
        """Check if API is accessible."""
        try:
            response = self._request('GET', '/health')
            return response.status_code == 200
        except Exception:
            return False


# Service-specific client
class JudicialAPIClient(APIClient):
    def get_cases(self, page: int = 1, limit: int = 20) -> dict:
        return self.get('/cases', params={'page': page, 'limit': limit})
    
    def create_case(self, case_data: dict) -> dict:
        return self.post('/cases', data=case_data)
    
    def get_case(self, case_id: str) -> dict:
        return self.get(f'/cases/{case_id}')

# Usage
client = JudicialAPIClient(
    base_url='https://api.judicialsolutions.in',
    api_key=os.environ['API_KEY']
)

if client.health_check():
    cases = client.get_cases(page=1, limit=50)
    print(f"Found {len(cases['items'])} cases")
```

---

## PART 5 — YAML/JSON PARSING AND MANIPULATION

```python
import yaml
import json
import os
from pathlib import Path
from typing import Any

# YAML parsing
def load_config(config_path: str) -> dict:
    """Load YAML config with environment variable substitution."""
    with open(config_path) as f:
        content = f.read()
    
    # Substitute environment variables: ${VAR_NAME}
    import re
    def replace_env_var(match):
        var_name = match.group(1)
        value = os.environ.get(var_name)
        if value is None:
            raise ValueError(f"Environment variable not set: {var_name}")
        return value
    
    content = re.sub(r'\$\{(\w+)\}', replace_env_var, content)
    return yaml.safe_load(content)

# config.yaml:
# database:
#   host: ${DB_HOST}
#   port: 5432
#   name: ${DB_NAME}

def merge_configs(base: dict, override: dict) -> dict:
    """Deep merge two config dicts."""
    result = base.copy()
    for key, value in override.items():
        if (
            key in result and
            isinstance(result[key], dict) and
            isinstance(value, dict)
        ):
            result[key] = merge_configs(result[key], value)
        else:
            result[key] = value
    return result

def load_environment_config(env: str, config_dir: str) -> dict:
    """Load base config merged with environment-specific overrides."""
    base = load_config(f"{config_dir}/base.yaml")
    env_config_path = f"{config_dir}/{env}.yaml"
    
    if Path(env_config_path).exists():
        env_config = load_config(env_config_path)
        return merge_configs(base, env_config)
    
    return base

# Kubernetes manifest manipulation
def update_deployment_image(manifest_path: str, new_image: str) -> dict:
    """Update container image in K8s deployment manifest."""
    with open(manifest_path) as f:
        manifest = yaml.safe_load(f)
    
    containers = manifest['spec']['template']['spec']['containers']
    for container in containers:
        if container['name'] == manifest['metadata']['name']:
            container['image'] = new_image
    
    with open(manifest_path, 'w') as f:
        yaml.dump(manifest, f, default_flow_style=False)
    
    return manifest

# JSON manipulation
def update_terraform_vars(tfvars_path: str, updates: dict):
    """Update Terraform variables JSON file."""
    with open(tfvars_path) as f:
        current = json.load(f)
    
    current.update(updates)
    
    with open(tfvars_path, 'w') as f:
        json.dump(current, f, indent=2)

# Parse CloudWatch metrics response
def extract_metric_values(cw_response: dict) -> list:
    """Extract metric data points from CloudWatch response."""
    datapoints = cw_response.get('Datapoints', [])
    # Sort by timestamp
    datapoints.sort(key=lambda x: x['Timestamp'])
    return [
        {
            'timestamp': dp['Timestamp'].isoformat(),
            'value': dp['Average'],
            'unit': dp['Unit']
        }
        for dp in datapoints
    ]
```

---

## PART 6 — PYTEST FOR DEVOPS

### Fixtures and conftest.py

```python
# conftest.py — shared fixtures for all tests

import pytest
import boto3
import os
from unittest.mock import MagicMock, patch
from moto import mock_s3, mock_ec2  # moto: mock AWS services

# Scope: function (default), class, module, session
@pytest.fixture(scope='session')
def aws_credentials():
    """Fake AWS credentials for testing."""
    os.environ['AWS_ACCESS_KEY_ID'] = 'testing'
    os.environ['AWS_SECRET_ACCESS_KEY'] = 'testing'
    os.environ['AWS_SECURITY_TOKEN'] = 'testing'
    os.environ['AWS_SESSION_TOKEN'] = 'testing'
    os.environ['AWS_DEFAULT_REGION'] = 'ap-south-1'
    yield
    # cleanup happens after all tests in session

@pytest.fixture
def s3_bucket(aws_credentials):
    """Create a real-ish S3 bucket using moto mock."""
    with mock_s3():
        s3 = boto3.client('s3', region_name='ap-south-1')
        s3.create_bucket(
            Bucket='test-bucket',
            CreateBucketConfiguration={'LocationConstraint': 'ap-south-1'}
        )
        yield s3  # test runs here
        # mock context exits — all resources cleaned up

@pytest.fixture
def api_client():
    """HTTP client fixture with base URL configured."""
    from src.api_client import APIClient
    return APIClient(
        base_url='http://localhost:8080',
        api_key='test-key-123'
    )

@pytest.fixture
def mock_ec2_manager():
    """Mock EC2Manager for unit tests."""
    with patch('src.ec2_manager.boto3') as mock_boto:
        mock_client = MagicMock()
        mock_boto.client.return_value = mock_client
        yield mock_client

@pytest.fixture(autouse=True)  # runs for every test in scope
def reset_environment(monkeypatch):
    """Reset environment variables before each test."""
    monkeypatch.delenv('API_KEY', raising=False)
    yield
```

### Test Writing Patterns

```python
# tests/test_s3_manager.py
import pytest
from moto import mock_s3
from src.s3_manager import S3Manager

class TestS3Manager:
    
    @mock_s3
    def test_upload_file(self, tmp_path, aws_credentials):
        """Test file upload to S3."""
        # Arrange
        import boto3
        s3 = boto3.client('s3', region_name='ap-south-1')
        s3.create_bucket(
            Bucket='test-bucket',
            CreateBucketConfiguration={'LocationConstraint': 'ap-south-1'}
        )
        
        manager = S3Manager('test-bucket')
        test_file = tmp_path / 'test.txt'
        test_file.write_text('hello world')
        
        # Act
        result = manager.upload_file(str(test_file), 'uploads/test.txt')
        
        # Assert
        assert result == 's3://test-bucket/uploads/test.txt'
        
        # Verify file is actually in S3
        response = s3.get_object(Bucket='test-bucket', Key='uploads/test.txt')
        content = response['Body'].read().decode()
        assert content == 'hello world'
    
    def test_upload_nonexistent_file(self):
        """Test that uploading missing file raises error."""
        manager = S3Manager('test-bucket')
        
        with pytest.raises(FileNotFoundError):
            manager.upload_file('/nonexistent/file.txt', 'key')
```

### Parametrize — Data-Driven Tests

```python
import pytest

# Test same function with multiple inputs
@pytest.mark.parametrize('instance_type,expected_vcpu', [
    ('t3.micro', 2),
    ('t3.small', 2),
    ('t3.medium', 2),
    ('m5.large', 2),
    ('m5.xlarge', 4),
    ('m5.2xlarge', 8),
])
def test_get_vcpu_count(instance_type, expected_vcpu):
    """Test vCPU count retrieval for different instance types."""
    from src.ec2_utils import get_vcpu_count
    assert get_vcpu_count(instance_type) == expected_vcpu

# Parametrize with indirect fixture
@pytest.mark.parametrize('environment,expected_count', [
    ('dev', 1),
    ('staging', 2),
    ('prod', 3)
])
def test_replica_count_per_environment(environment, expected_count):
    from src.config import get_replica_count
    assert get_replica_count(environment) == expected_count

# Parametrize with IDs for readable test names
@pytest.mark.parametrize('status_code,should_retry', [
    pytest.param(200, False, id='success'),
    pytest.param(429, True, id='rate_limited'),
    pytest.param(500, True, id='server_error'),
    pytest.param(404, False, id='not_found'),
])
def test_should_retry(status_code, should_retry):
    from src.api_client import should_retry_request
    assert should_retry_request(status_code) == should_retry
```

### Mocking

```python
from unittest.mock import patch, MagicMock, call
import pytest

def test_deploy_calls_aws_apis():
    """Test that deploy function calls correct AWS APIs."""
    with patch('src.deployer.boto3') as mock_boto:
        # Set up mock
        mock_lambda = MagicMock()
        mock_boto.client.return_value = mock_lambda
        mock_lambda.update_function_code.return_value = {
            'FunctionArn': 'arn:aws:lambda:...',
            'State': 'Active'
        }
        
        # Act
        from src.deployer import deploy_lambda
        deploy_lambda('my-function', '/tmp/code.zip')
        
        # Assert mock was called with correct args
        mock_boto.client.assert_called_once_with(
            'lambda',
            region_name='ap-south-1'
        )
        mock_lambda.update_function_code.assert_called_once()
        
        # Check specific arguments
        call_kwargs = mock_lambda.update_function_code.call_args.kwargs
        assert call_kwargs['FunctionName'] == 'my-function'

def test_health_check_retries_on_failure():
    """Test that health check retries 3 times before giving up."""
    with patch('src.health_check.requests.get') as mock_get:
        # Mock to fail twice then succeed
        mock_get.side_effect = [
            ConnectionError("Connection refused"),
            ConnectionError("Connection refused"),
            MagicMock(status_code=200, json=lambda: {'status': 'ok'})
        ]
        
        from src.health_check import check_service_health
        result = check_service_health('http://my-service/health')
        
        assert result == True
        assert mock_get.call_count == 3  # called 3 times

# pytest-mock (cleaner than unittest.mock)
def test_send_slack_notification(mocker):  # mocker fixture from pytest-mock
    mock_post = mocker.patch('requests.post')
    mock_post.return_value.status_code = 200
    
    from src.notifier import send_slack_alert
    send_slack_alert('Deployment successful', '#devops')
    
    mock_post.assert_called_once()
    call_args = mock_post.call_args
    assert '#devops' in str(call_args)
```

### Markers and Test Organisation

```python
import pytest

# Custom markers (register in pytest.ini or conftest.py)
# pytest.ini:
# [pytest]
# markers =
#     smoke: Quick sanity tests
#     integration: Tests requiring real AWS
#     slow: Tests taking > 10 seconds
#     unit: Pure unit tests (no external deps)

@pytest.mark.smoke
def test_api_health():
    """Quick smoke test — runs in CI on every push."""
    pass

@pytest.mark.integration
@pytest.mark.slow
def test_full_deployment_workflow():
    """Integration test — runs only in staging pipeline."""
    pass

@pytest.mark.skip(reason="AWS account not configured in CI")
def test_real_aws_operation():
    pass

@pytest.mark.skipif(
    os.environ.get('ENV') != 'staging',
    reason="Only run in staging environment"
)
def test_staging_specific():
    pass

# Run specific markers:
# pytest -m smoke
# pytest -m "not slow"
# pytest -m "unit and not integration"
```

---

## PART 7 — SHELL COMMAND EXECUTION

### subprocess Advanced Patterns

```python
import subprocess
import asyncio
import threading
from queue import Queue

# Async command execution
async def run_async(cmd: list) -> tuple:
    """Run command asynchronously."""
    process = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    stdout, stderr = await process.communicate()
    return process.returncode, stdout.decode(), stderr.decode()

async def run_parallel_commands(commands: list) -> list:
    """Run multiple commands in parallel."""
    tasks = [run_async(cmd) for cmd in commands]
    results = await asyncio.gather(*tasks)
    return results

# Usage: check health of multiple services simultaneously
async def check_all_services():
    services = [
        ['curl', '-f', 'http://service-a/health'],
        ['curl', '-f', 'http://service-b/health'],
        ['curl', '-f', 'http://service-c/health'],
    ]
    results = await run_parallel_commands(services)
    for (code, stdout, stderr), service in zip(results, services):
        status = 'UP' if code == 0 else 'DOWN'
        print(f"{service[2]}: {status}")

asyncio.run(check_all_services())

# paramiko — SSH to remote machines
def run_on_remote(host: str, username: str, key_path: str, command: str) -> str:
    """Execute command on remote server via SSH."""
    import paramiko
    
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(
            hostname=host,
            username=username,
            key_filename=key_path,
            timeout=30
        )
        
        stdin, stdout, stderr = client.exec_command(command)
        exit_code = stdout.channel.recv_exit_status()
        
        output = stdout.read().decode()
        error = stderr.read().decode()
        
        if exit_code != 0:
            raise Exception(f"Remote command failed: {error}")
        
        return output
    finally:
        client.close()

# Deploy to multiple servers
def rolling_deploy(servers: list, key_path: str, deploy_cmd: str):
    """Deploy to servers one at a time (rolling)."""
    for i, server in enumerate(servers):
        print(f"Deploying to {server} ({i+1}/{len(servers)})")
        
        output = run_on_remote(
            host=server,
            username='ec2-user',
            key_path=key_path,
            command=deploy_cmd
        )
        print(f"Output: {output}")
        
        # Health check before moving to next server
        health = run_on_remote(
            host=server,
            username='ec2-user',
            key_path=key_path,
            command='curl -f http://localhost:8080/health'
        )
        print(f"Health: {health}")
```

---

## PART 8 — LOGGING AND ERROR HANDLING

### Structured Logging

```python
import logging
import json
import sys
from datetime import datetime
from typing import Any

class JSONFormatter(logging.Formatter):
    """Format logs as JSON for CloudWatch/ELK ingestion."""
    
    def format(self, record: logging.LogRecord) -> str:
        log_data = {
            'timestamp': datetime.utcnow().isoformat(),
            'level': record.levelname,
            'logger': record.name,
            'message': record.getMessage(),
            'function': record.funcName,
            'line': record.lineno,
        }
        
        # Include exception info if present
        if record.exc_info:
            log_data['exception'] = self.formatException(record.exc_info)
        
        # Include extra fields
        for key, value in record.__dict__.items():
            if key not in logging.LogRecord.__dict__ and \
               not key.startswith('_') and \
               key not in ('msg', 'args', 'exc_info', 'exc_text'):
                log_data[key] = value
        
        return json.dumps(log_data)

def setup_logging(service_name: str, level: str = 'INFO') -> logging.Logger:
    """Configure structured logging for a service."""
    logger = logging.getLogger(service_name)
    logger.setLevel(getattr(logging, level.upper()))
    
    # Console handler with JSON format
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JSONFormatter())
    logger.addHandler(handler)
    
    return logger

# Usage
logger = setup_logging('judicial-api')

def process_request(request_id: str, user_id: str):
    logger.info(
        "Processing request",
        extra={
            'request_id': request_id,
            'user_id': user_id,
            'environment': os.environ.get('ENV', 'dev')
        }
    )
    # CloudWatch output:
    # {"timestamp": "...", "level": "INFO", "message": "Processing request",
    #  "request_id": "abc123", "user_id": "u456", "environment": "prod"}
```

### Error Handling Patterns

```python
import traceback
from functools import wraps
from typing import TypeVar, Callable

T = TypeVar('T')

class DeploymentError(Exception):
    """Base exception for deployment failures."""
    def __init__(self, message: str, details: dict = None):
        super().__init__(message)
        self.details = details or {}

class AWSResourceError(DeploymentError):
    """AWS-specific resource errors."""
    pass

class HealthCheckError(DeploymentError):
    """Service health check failures."""
    pass

def handle_aws_errors(func: Callable) -> Callable:
    """Decorator to convert botocore exceptions to custom exceptions."""
    @wraps(func)
    def wrapper(*args, **kwargs):
        from botocore.exceptions import ClientError, NoCredentialsError
        try:
            return func(*args, **kwargs)
        except NoCredentialsError:
            raise AWSResourceError(
                "AWS credentials not configured",
                {'hint': 'Check AWS_ACCESS_KEY_ID and region'}
            )
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_msg = e.response['Error']['Message']
            raise AWSResourceError(
                f"AWS API error: {error_code}",
                {'code': error_code, 'message': error_msg}
            )
    return wrapper

# Comprehensive error handling in deployment script
def safe_deploy(function_name: str, zip_path: str) -> dict:
    """Deploy with full error handling and rollback."""
    logger = logging.getLogger(__name__)
    
    # Get current version for rollback
    lambda_client = boto3.client('lambda')
    current_config = lambda_client.get_function_configuration(
        FunctionName=function_name
    )
    current_version = current_config.get('Version', '$LATEST')
    
    try:
        logger.info(f"Deploying {function_name}")
        
        # Deploy new version
        result = update_lambda_function(function_name, zip_path)
        
        # Verify deployment
        health = verify_lambda_health(function_name)
        if not health['healthy']:
            raise HealthCheckError(
                "Post-deployment health check failed",
                health
            )
        
        logger.info(f"Deployment successful: {function_name}")
        return {'success': True, 'version': result['version']}
    
    except HealthCheckError as e:
        logger.error(f"Health check failed, rolling back: {e}")
        rollback(function_name, current_version)
        return {'success': False, 'error': str(e), 'rolled_back': True}
    
    except AWSResourceError as e:
        logger.error(f"AWS error during deployment: {e}", extra=e.details)
        return {'success': False, 'error': str(e), 'rolled_back': False}
    
    except Exception as e:
        logger.critical(
            f"Unexpected error: {e}",
            extra={'traceback': traceback.format_exc()}
        )
        raise
```

---

## PART 9 — PYTHON IN CI/CD PIPELINES

### GitHub Actions with Python

```yaml
# .github/workflows/python-ci.yml
name: Python CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: 'pip'  # cache pip downloads
      
      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install -r requirements-test.txt
      
      - name: Lint
        run: |
          flake8 src/ --max-line-length=100
          black --check src/
          isort --check-only src/
      
      - name: Type check
        run: mypy src/ --ignore-missing-imports
      
      - name: Unit tests
        run: |
          pytest tests/unit/ \
            -v \
            --cov=src \
            --cov-report=xml \
            --cov-report=html \
            -m "not integration"
      
      - name: Coverage check
        run: coverage report --fail-under=80
      
      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: coverage.xml

  integration-test:
    needs: test
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-south-1
      
      - name: Run integration tests
        run: |
          pytest tests/integration/ \
            -v \
            -m integration \
            --html=reports/integration-report.html \
            --self-contained-html
        env:
          API_URL: ${{ secrets.STAGING_API_URL }}
          API_KEY: ${{ secrets.STAGING_API_KEY }}
      
      - name: Upload test report
        uses: actions/upload-artifact@v4
        if: always()  # upload even if tests fail
        with:
          name: integration-test-report
          path: reports/
```

### Python Deployment Scripts

```python
#!/usr/bin/env python3
"""
deploy.py — Main deployment script called from CI/CD
Usage: python deploy.py --env prod --service judicial-api --version 1.2.3
"""
import argparse
import logging
import sys
import boto3
from datetime import datetime

def parse_args():
    parser = argparse.ArgumentParser(description='Deploy service to AWS')
    parser.add_argument('--env', required=True, choices=['dev', 'staging', 'prod'])
    parser.add_argument('--service', required=True)
    parser.add_argument('--version', required=True)
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--timeout', type=int, default=300)
    return parser.parse_args()

def main():
    args = parse_args()
    logger = setup_logging('deploy')
    
    logger.info("Starting deployment", extra={
        'environment': args.env,
        'service': args.service,
        'version': args.version,
        'dry_run': args.dry_run
    })
    
    try:
        if args.dry_run:
            logger.info("DRY RUN — no changes will be made")
            return 0
        
        # Deploy
        result = deploy_service(args.env, args.service, args.version)
        
        # Report to CloudWatch
        push_deployment_metric(
            service=args.service,
            environment=args.env,
            success=result['success']
        )
        
        if result['success']:
            logger.info("Deployment complete", extra=result)
            return 0
        else:
            logger.error("Deployment failed", extra=result)
            return 1
    
    except KeyboardInterrupt:
        logger.warning("Deployment interrupted by user")
        return 130
    except Exception as e:
        logger.critical(f"Unexpected failure: {e}", exc_info=True)
        return 1

if __name__ == '__main__':
    sys.exit(main())
```

---

## PART 10 — REAL SCRIPTS FROM YOUR RESUME

### Health Check Script (30 min → 5 min incident response)

```python
#!/usr/bin/env python3
"""
health_check.py — Service health monitoring script
From your resume: "cutting incident response prep time from 30 min to under 5 min"
"""
import boto3
import requests
import json
import logging
import os
import sys
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field
from typing import Optional

logger = logging.getLogger(__name__)

@dataclass
class ServiceCheck:
    name: str
    url: str
    expected_status: int = 200
    timeout: int = 10
    critical: bool = True  # if True, overall health fails if this fails

@dataclass
class HealthResult:
    service: str
    healthy: bool
    status_code: Optional[int] = None
    response_time_ms: Optional[float] = None
    error: Optional[str] = None
    details: dict = field(default_factory=dict)

class HealthChecker:
    def __init__(self, region='ap-south-1'):
        self.cw = boto3.client('cloudwatch', region_name=region)
        self.services = []
    
    def add_service(self, check: ServiceCheck):
        self.services.append(check)
    
    def check_service(self, check: ServiceCheck) -> HealthResult:
        """Check a single service health endpoint."""
        start = datetime.utcnow()
        
        try:
            response = requests.get(
                check.url,
                timeout=check.timeout,
                headers={'User-Agent': 'HealthChecker/1.0'}
            )
            
            elapsed = (datetime.utcnow() - start).total_seconds() * 1000
            healthy = response.status_code == check.expected_status
            
            try:
                body = response.json()
            except Exception:
                body = {}
            
            return HealthResult(
                service=check.name,
                healthy=healthy,
                status_code=response.status_code,
                response_time_ms=elapsed,
                details=body
            )
        
        except requests.Timeout:
            return HealthResult(
                service=check.name,
                healthy=False,
                error=f"Timeout after {check.timeout}s"
            )
        except requests.ConnectionError as e:
            return HealthResult(
                service=check.name,
                healthy=False,
                error=f"Connection failed: {e}"
            )
        except Exception as e:
            return HealthResult(
                service=check.name,
                healthy=False,
                error=f"Unexpected error: {e}"
            )
    
    def check_all(self, parallel: bool = True) -> list:
        """Check all services, optionally in parallel."""
        if parallel:
            with ThreadPoolExecutor(max_workers=10) as executor:
                futures = {
                    executor.submit(self.check_service, svc): svc
                    for svc in self.services
                }
                results = []
                for future in as_completed(futures):
                    results.append(future.result())
        else:
            results = [self.check_service(svc) for svc in self.services]
        
        return results
    
    def push_to_cloudwatch(self, results: list):
        """Push health metrics to CloudWatch."""
        metric_data = []
        
        for result in results:
            metric_data.extend([
                {
                    'MetricName': 'ServiceHealth',
                    'Dimensions': [{'Name': 'Service', 'Value': result.service}],
                    'Value': 1 if result.healthy else 0,
                    'Unit': 'Count',
                    'Timestamp': datetime.utcnow()
                }
            ])
            
            if result.response_time_ms is not None:
                metric_data.append({
                    'MetricName': 'ResponseTime',
                    'Dimensions': [{'Name': 'Service', 'Value': result.service}],
                    'Value': result.response_time_ms,
                    'Unit': 'Milliseconds',
                    'Timestamp': datetime.utcnow()
                })
        
        if metric_data:
            self.cw.put_metric_data(
                Namespace='JudicialSolutions/Services',
                MetricData=metric_data
            )
    
    def generate_report(self, results: list) -> dict:
        """Generate health report."""
        critical_failures = [
            r for r in results
            if not r.healthy and any(
                s.name == r.service and s.critical
                for s in self.services
            )
        ]
        
        report = {
            'timestamp': datetime.utcnow().isoformat(),
            'overall_healthy': len(critical_failures) == 0,
            'total_services': len(results),
            'healthy_count': sum(1 for r in results if r.healthy),
            'failed_count': sum(1 for r in results if not r.healthy),
            'services': [
                {
                    'name': r.service,
                    'healthy': r.healthy,
                    'status_code': r.status_code,
                    'response_time_ms': r.response_time_ms,
                    'error': r.error
                }
                for r in results
            ]
        }
        
        return report


def main():
    checker = HealthChecker()
    
    # Add services to check
    services = [
        ServiceCheck('API Gateway', os.environ.get('API_URL', '') + '/health'),
        ServiceCheck('Database', os.environ.get('DB_HEALTH_URL', ''), critical=True),
        ServiceCheck('Auth Service', os.environ.get('AUTH_URL', '') + '/health'),
        ServiceCheck('CDN', 'https://judicialsolutions.in/health', critical=False),
    ]
    
    for svc in services:
        if svc.url:
            checker.add_service(svc)
    
    # Run checks
    results = checker.check_all(parallel=True)
    
    # Push metrics
    checker.push_to_cloudwatch(results)
    
    # Generate and print report
    report = checker.generate_report(results)
    print(json.dumps(report, indent=2, default=str))
    
    # Exit code signals overall health to CI/CD
    return 0 if report['overall_healthy'] else 1


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    sys.exit(main())
```

### Environment Validation Script

```python
#!/usr/bin/env python3
"""
validate_env.py — Pre-deployment environment validation
Validates: AWS connectivity, required secrets, service endpoints
"""
import boto3
import os
import sys
import json
from typing import List, Tuple
from botocore.exceptions import ClientError, NoCredentialsError

class EnvironmentValidator:
    def __init__(self, environment: str):
        self.environment = environment
        self.errors = []
        self.warnings = []
    
    def check(self, name: str, condition: bool, error_msg: str, warning: bool = False):
        """Record a check result."""
        if not condition:
            if warning:
                self.warnings.append(f"[WARN] {name}: {error_msg}")
            else:
                self.errors.append(f"[FAIL] {name}: {error_msg}")
        else:
            print(f"[PASS] {name}")
    
    def validate_aws_credentials(self):
        """Verify AWS credentials work."""
        try:
            sts = boto3.client('sts')
            identity = sts.get_caller_identity()
            self.check(
                'AWS Credentials',
                True,
                ''
            )
            print(f"  → Account: {identity['Account']}, ARN: {identity['Arn']}")
        except NoCredentialsError:
            self.check('AWS Credentials', False, 'No AWS credentials found')
        except Exception as e:
            self.check('AWS Credentials', False, str(e))
    
    def validate_required_env_vars(self, required_vars: List[str]):
        """Check all required environment variables are set."""
        for var in required_vars:
            value = os.environ.get(var)
            self.check(
                f'Env var: {var}',
                value is not None and value != '',
                f'Not set or empty'
            )
    
    def validate_s3_bucket(self, bucket_name: str):
        """Verify S3 bucket exists and is accessible."""
        try:
            s3 = boto3.client('s3')
            s3.head_bucket(Bucket=bucket_name)
            self.check(f'S3 bucket: {bucket_name}', True, '')
        except ClientError as e:
            error_code = e.response['Error']['Code']
            self.check(
                f'S3 bucket: {bucket_name}',
                False,
                f'Error {error_code}: {e}'
            )
    
    def validate_lambda_function(self, function_name: str):
        """Check Lambda function exists and is active."""
        try:
            lambda_client = boto3.client('lambda')
            config = lambda_client.get_function_configuration(
                FunctionName=function_name
            )
            state = config.get('State', 'Unknown')
            self.check(
                f'Lambda: {function_name}',
                state == 'Active',
                f'State is {state}, expected Active'
            )
        except ClientError:
            self.check(f'Lambda: {function_name}', False, 'Function not found')
    
    def run(self) -> bool:
        """Run all validations and return True if all pass."""
        print(f"\n=== Validating {self.environment} environment ===\n")
        
        self.validate_aws_credentials()
        
        required_vars = ['AWS_REGION', 'API_KEY', 'DB_HOST']
        self.validate_required_env_vars(required_vars)
        
        self.validate_s3_bucket(f'judicial-{self.environment}-assets')
        self.validate_lambda_function(f'judicial-api-{self.environment}')
        
        print(f"\n=== Results ===")
        print(f"Errors:   {len(self.errors)}")
        print(f"Warnings: {len(self.warnings)}")
        
        for error in self.errors:
            print(error)
        for warning in self.warnings:
            print(warning)
        
        return len(self.errors) == 0

if __name__ == '__main__':
    env = os.environ.get('ENVIRONMENT', 'dev')
    validator = EnvironmentValidator(env)
    success = validator.run()
    sys.exit(0 if success else 1)
```

---

## INTERVIEW QUESTIONS RAPID FIRE

**Q: What's the difference between `subprocess.run` and `os.system`?**
```
os.system:
  Runs in shell — vulnerable to shell injection
  Returns only exit code
  No output capture
  Never use with user input

subprocess.run:
  More control — can avoid shell (safer)
  Captures stdout/stderr
  Returns CompletedProcess with all details
  Use: subprocess.run(['cmd', 'arg'], check=True)
  Avoid: subprocess.run('cmd arg', shell=True) with user input
```

**Q: How do you test code that calls AWS APIs without making real API calls?**
```
Option 1: unittest.mock.patch
  @patch('boto3.client')
  def test_something(mock_client):
      mock_client.return_value.get_object.return_value = {...}

Option 2: moto library (recommended)
  @mock_s3
  def test_s3_operation():
      # Creates in-memory fake S3
      s3 = boto3.client('s3')
      s3.create_bucket(Bucket='test')
      # real boto3 calls work against fake

Option 3: localstack (Docker-based full AWS mock)
  Heavier but most realistic
  Good for integration tests
```

**Q: What is the difference between `@pytest.fixture` scope options?**
```
function (default): new fixture per test function — isolated
class:   shared within test class
module:  shared within test file
session: shared across entire test run (one instance)

Use session for: expensive setup (DB connection, AWS client)
Use function for: anything that modifies state
```

**Q: How do you handle a Python script that needs to run for hours without crashing?**
```
1. Retry with exponential backoff on transient errors
2. Checkpoint progress (save to file/DynamoDB)
3. Handle SIGTERM gracefully (can resume from checkpoint)
4. Structured logging with correlation IDs
5. Push metrics to CloudWatch (alive + progress)
6. Run as long-lived process with supervisor (systemd, supervisor)
7. Or: break into smaller Lambda functions with SQS between them
```
