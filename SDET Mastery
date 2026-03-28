# 🧪 SDET Mastery — Python & Pytest Deep Dive

> **Target:** 3.5 YOE SDET | Theory-first, then hands-on code

-----

## 📍 Table of Contents

1. [Overview & Roadmap](#overview--roadmap)
1. [Module 01 — OOP for SDET](#module-01--oop-for-sdet)
1. [Module 02 — Decorators & Generators](#module-02--decorators--generators)
1. [Module 03 — Fixtures & conftest.py](#module-03--fixtures--conftestpy)
1. [Module 04 — Markers & Parametrize](#module-04--markers--parametrize)
1. [Module 05 — REST API Testing](#module-05--rest-api-testing)
1. [Module 06 — Mocking & Patching](#module-06--mocking--patching)
1. [Module 07 — Page Object, AAA & BDD](#module-07--page-object-aaa--bdd)
1. [Module 08 — Data-Driven Testing](#module-08--data-driven-testing)
1. [Module 09 — CI/CD Integration](#module-09--cicd-integration)
1. [Module 10 — Test Reporting](#module-10--test-reporting)
1. [Module 11 — CAFY Framework (Cisco)](#module-11--cafy-framework-cisco)
1. [Quick Reference Cheatsheet](#quick-reference-cheatsheet)

-----

## Overview & Roadmap

|# |Module                 |Key Topics                              |Difficulty   |
|--|-----------------------|----------------------------------------|-------------|
|01|OOP for SDET           |ABCs, dataclasses, composition          |🟡 Medium     |
|02|Decorators & Generators|retry, functools.wraps, yield           |🟡 Medium     |
|03|Fixtures & conftest    |Scopes, teardown, autouse               |🔴 Hard       |
|04|Markers & Parametrize  |Custom markers, cartesian product       |🟡 Medium     |
|05|REST API Testing       |requests, jsonschema, 5-layer assertions|🔴 Hard       |
|06|Mocking & Patching     |MagicMock, patch, mocker                |🔴 Hard       |
|07|Design Patterns        |POM, AAA, BDD, Gherkin                  |🟡 Medium     |
|08|Data-Driven Testing    |CSV/JSON inputs, generators             |🟢 Easy–Medium|
|09|CI/CD Integration      |GitHub Actions, parallel, artifacts     |🔴 Hard       |
|10|Test Reporting         |Allure, pytest-html, JUnit XML          |🟡 Medium     |
|11|CAFY Framework         |Cisco trigger/verification, testbed YAML|🔴 Hard       |

### Recommended Study Order

```
[01] OOP + Decorators + Generators
        ↓
[02] Pytest Core — Fixtures, Markers, Parametrize
        ↓
[03] REST API Testing + Mocking
        ↓
[04] Design Patterns — POM, AAA, BDD
        ↓
[05] CI/CD + Reporting + CAFY
```

-----

## Module 01 — OOP for SDET

> Object-Oriented Programming is the backbone of scalable test frameworks. Master classes, inheritance, and abstraction with testing in mind.

### 1.1 Why OOP in Testing?

At 3.5 YOE, you’re designing **test systems**, not just writing tests. OOP gives you tools to model the application under test, share logic, and scale without duplication.

|Pillar           |SDET Application                       |
|-----------------|---------------------------------------|
|**Encapsulation**|Hide locators inside Page Objects      |
|**Inheritance**  |Share setup/teardown in `BasePage`     |
|**Polymorphism** |Override behavior per environment      |
|**Abstraction**  |Hide complexity behind clean interfaces|

### 1.2 Classes, `__init__`, and Properties

```python
from abc import ABC, abstractmethod
from selenium.webdriver.remote.webdriver import WebDriver

class BasePage(ABC):
    """Abstract base class for all Page Objects."""

    def __init__(self, driver: WebDriver):
        # Encapsulate the driver — callers don't touch it directly
        self._driver = driver
        self._base_url = "https://app.example.com"

    @property
    def title(self) -> str:
        return self._driver.title

    @abstractmethod
    def load(self) -> None:
        """Every page must implement how it loads itself."""
        ...

    def navigate_to(self, path: str) -> None:
        # Shared by ALL child pages — defined once
        self._driver.get(f"{self._base_url}/{path}")


class LoginPage(BasePage):
    # Locators encapsulated as class-level constants
    _USERNAME = ("id", "username")
    _PASSWORD = ("id", "password")
    _SUBMIT   = ("css selector", "button[type='submit']")

    def load(self) -> None:  # fulfills abstract contract
        self.navigate_to("login")

    def login(self, user: str, pwd: str) -> None:
        self._driver.find_element(*self._USERNAME).send_keys(user)
        self._driver.find_element(*self._PASSWORD).send_keys(pwd)
        self._driver.find_element(*self._SUBMIT).click()
```

> **Interview tip:** “Why use ABC?” — It enforces contracts. If a subclass forgets to implement `load()`, Python raises `TypeError` at instantiation, not at runtime 10 minutes into a test run.

### 1.3 Inheritance vs. Composition

Prefer **composition over inheritance** for test helpers. Inheritance is for the `BasePage`/`BaseTest` pattern; composition is for utilities like a logger, API client, or data factory injected into your page objects.

```python
class APIClient:
    """Reusable HTTP client — inject, don't inherit."""
    def __init__(self, base_url: str, token: str):
        self.session = requests.Session()
        self.session.headers["Authorization"] = f"Bearer {token}"
        self.base_url = base_url

    def get(self, endpoint: str, **kwargs):
        return self.session.get(f"{self.base_url}{endpoint}", **kwargs)


class UserService:
    """Compose APIClient — not inherit it."""
    def __init__(self, client: APIClient):
        self._client = client   # injected dependency

    def get_user(self, user_id: int) -> dict:
        resp = self._client.get(f"/users/{user_id}")
        resp.raise_for_status()
        return resp.json()
```

### 1.4 Dataclasses for Test Data

Stop using plain dicts. `@dataclass` gives typed, readable test data models with auto-generated `__repr__` and `__eq__` — perfect for assertions.

```python
from dataclasses import dataclass, field
from typing import Optional

@dataclass
class User:
    username: str
    email: str
    role: str = "viewer"
    permissions: list = field(default_factory=list)
    id: Optional[int] = None   # set after API creation

# In tests — readable and comparable:
expected = User(username="alice", email="alice@test.com", role="admin")
actual   = User(**api_response["data"])

assert actual.role == expected.role   # clean, not dict["role"]
assert actual == expected              # __eq__ is auto-generated
```

### 🏋️ Exercises

**Exercise 1 — Build a BasePage** *(Easy)*

- Create an abstract `BasePage` with abstract `load()` and concrete `wait_for_element()`
- Implement `ProductPage(BasePage)` with locators as class constants
- Add a `@property` for `product_price` that parses `"$29.99"` → `float(29.99)`
- Verify that instantiating `BasePage` directly raises `TypeError`

**Exercise 2 — APIClient Composition** *(Medium)*

- Build `APIClient` with `requests.Session` supporting `get/post/put/delete`
- Build `UserService` using composition — `self._client = client`
- Add `create_user()`, `get_user()`, `delete_user()` — each raises on 4xx/5xx
- Write a pytest test using the `responses` library to mock the HTTP layer

**Exercise 3 — Dataclass Test Models** *(Medium)*

- Define `@dataclass User` with: id, username, email, role, is_active
- Add a `@classmethod from_api_response(cls, data: dict)` factory
- Add `__post_init__` to validate email contains “@”
- Write parametrized tests using these models as input

### 🧠 Quiz

|Q|Question                                                                                              |Answer                                                                          |
|-|------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------|
|1|What happens if you instantiate a class inheriting from ABC without implementing all abstract methods?|`TypeError` is raised at **instantiation time**                                 |
|2|Best reason to prefer `@dataclass` over plain dict for test data?                                     |Typed fields, auto `__eq__` for assertions, auto `__repr__` for failure messages|
|3|Why prefer composition over inheritance for utility classes in testing?                               |Avoids tight coupling and makes mocking/replacing dependencies easy             |

-----

## Module 02 — Decorators & Generators

> Write retry decorators, timing wrappers, and memory-efficient test data generators.

### 2.1 How Decorators Work

A decorator is a function that takes a function and returns a function. `@syntax` is sugar for `func = decorator(func)`.

```python
import functools
import time

def timeit(func):
    """Decorator that logs execution time of a test step."""
    @functools.wraps(func)   # preserves __name__, __doc__
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        result = func(*args, **kwargs)
        elapsed = time.perf_counter() - start
        print(f"[PERF] {func.__name__} took {elapsed:.3f}s")
        return result
    return wrapper

@timeit
def test_login_performance():
    page.login("alice", "pass")
    assert page.is_logged_in()
```

> **Always use `@functools.wraps(func)`** inside your decorator. Without it, `func.__name__` shows `"wrapper"` — this breaks pytest’s test discovery and error messages.

### 2.2 Retry Decorator — Real SDET Pattern

```python
def retry(max_attempts=3, delay=1.0, exceptions=(Exception,)):
    """Parametrized retry decorator for flaky test steps."""
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            last_exc = None
            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                except exceptions as exc:
                    last_exc = exc
                    if attempt < max_attempts - 1:
                        time.sleep(delay)
            raise last_exc
        return wrapper
    return decorator

# Usage — retry up to 3x on connection errors, 2s apart
@retry(max_attempts=3, delay=2.0, exceptions=(ConnectionError, TimeoutError))
def fetch_device_status(device_id):
    return api.get(f"/devices/{device_id}/status")
```

### 2.3 Generators for Test Data

Generators use `yield` to produce values lazily — for large data sets this prevents memory blowouts.

```python
import csv
from typing import Generator

def load_test_data(filepath: str) -> Generator[dict, None, None]:
    """Yield rows one at a time — no full CSV in memory."""
    with open(filepath) as f:
        reader = csv.DictReader(f)
        for row in reader:
            yield row  # pauses here, resumes on next()

# Generator expression (even leaner for transforms):
valid_users = (
    row for row in load_test_data("users.csv")
    if row["is_active"] == "true"
)

# In parametrize — converts to list when needed:
@pytest.mark.parametrize("user", list(load_test_data("users.csv")))
def test_user_login(user):
    assert login(user["email"], user["password"]) == "success"
```

> **Generator vs List:** A list loads everything into RAM. A generator loads one item at a time. For 50k test rows, this is the difference between 500MB memory and 1KB.

### 🏋️ Exercises

**Exercise 1 — Logging Decorator** *(Easy)*

- Write `@log_step(step_name)` that prints `[STEP] {name} — START` and `[STEP] {name} — PASS/FAIL`
- On exception, log FAIL and re-raise
- Use `@functools.wraps`
- Verify output using `capsys` fixture

**Exercise 2 — Infinite Test ID Generator** *(Medium)*

- Build a generator yielding `TC-0001, TC-0002...` using `itertools.count`
- Wrap in a `contextmanager` that resets the counter
- Write a test that generates 100 IDs and verifies no duplicates

### 🧠 Quiz

|Q|Question                                               |Answer                                                                              |
|-|-------------------------------------------------------|------------------------------------------------------------------------------------|
|1|Purpose of `@functools.wraps(func)` inside a decorator?|Copies `__name__`, `__doc__`, `__module__` from the original function to the wrapper|
|2|What does `yield` mean in a generator function?        |The function pauses at yield, retains local state, and resumes on the next iteration|

-----

## Module 03 — Fixtures & conftest.py

> Fixtures are pytest’s dependency injection system. Master scopes, teardown, autouse, and the conftest hierarchy.

### 3.1 Fixture Scopes

Scope determines **how many times a fixture is set up and torn down**. Getting this wrong is the #1 cause of slow or flaky test suites.

```python
import pytest

@pytest.fixture(scope="session")   # once per test RUN
def auth_token():
    token = api.get_token(user="test_admin")
    yield token
    api.revoke_token(token)           # teardown after all tests

@pytest.fixture(scope="module")    # once per .py file
def db_connection(auth_token):
    conn = Database.connect(token=auth_token)
    yield conn
    conn.close()

@pytest.fixture(scope="function")  # DEFAULT — once per test
def test_user(db_connection):
    user = db_connection.create_user("temp_user@test.com")
    yield user
    db_connection.delete_user(user.id)  # cleanup after EACH test
```

> **Scope hierarchy:** `session` > `package` > `module` > `class` > `function`
> A wider-scope fixture **cannot** depend on a narrower one.

### 3.2 conftest.py — The Hierarchy

```
tests/
├── conftest.py          # session fixtures: auth_token, base_url
├── api/
│   ├── conftest.py      # api-specific: api_client, api_headers
│   └── test_users.py    # has access to BOTH conftest files
└── ui/
    ├── conftest.py      # ui-specific: driver, screenshots
    └── test_login.py    # has access to BOTH conftest files
```

> **Rule of thumb:** Put fixtures in the conftest at the highest level where ALL tests that need them live.

### 3.3 autouse, params, and yield teardown

```python
# autouse=True — applied to ALL tests in scope without explicit request
@pytest.fixture(autouse=True, scope="function")
def reset_db_state(db_connection):
    yield  # test runs here
    db_connection.rollback()  # always runs after test

# Parametrized fixture — creates multiple test variants
@pytest.fixture(params=["chrome", "firefox", "safari"])
def browser(request):
    driver = create_driver(request.param)
    yield driver
    driver.quit()
# Every test using `browser` runs 3x — once per browser

# request.addfinalizer — alternative to yield teardown
@pytest.fixture
def cleanup_files(request, tmp_path):
    created = []
    def _cleanup():
        for f in created:
            f.unlink(missing_ok=True)
    request.addfinalizer(_cleanup)  # runs even on test FAILURE
    return created
```

> **`yield` vs `addfinalizer`:** `yield` teardown does NOT run if the fixture setup itself raises an exception. Use `request.addfinalizer` if you need guaranteed cleanup even when setup fails.

### 🏋️ Exercises

**Exercise 1 — Scoped Fixture Chain** *(Medium)*

- Session-scoped `api_token` fixture that logs in once
- Module-scoped `api_client` that uses the token
- Function-scoped `test_user` that creates and deletes a user per test
- Verify scope by adding print statements and checking `pytest -s` output

**Exercise 2 — conftest.py Architecture** *(Hard)*

- Root conftest: `env_config`, `auth_token`
- api/ conftest: `api_client(auth_token)`, `api_headers`
- ui/ conftest: `driver(request)` — parametrized with chrome/firefox
- Demonstrate that `api/test_users.py` cannot access the `driver` fixture from `ui/`

### 🧠 Quiz

|Q|Question                                                                              |Answer                                                                           |
|-|--------------------------------------------------------------------------------------|---------------------------------------------------------------------------------|
|1|A `session`-scoped fixture tries to request a `function`-scoped fixture. What happens?|pytest raises a `ScopeMismatch` error                                            |
|2|Primary difference between `yield` teardown and `request.addfinalizer`?               |`addfinalizer` runs even if fixture setup itself fails; `yield` teardown does not|

-----

## Module 04 — Markers & Parametrize

> `pytest.mark` lets you categorize, skip, and parametrize tests. Parametrize is the most powerful tool for data-driven testing.

### 4.1 Built-in Markers

```python
@pytest.mark.skip(reason="Bug #1234 — login broken")
def test_login_sso(): ...

@pytest.mark.skipif(
    sys.platform == "win32",
    reason="Unix-only test"
)
def test_symlink_creation(): ...

@pytest.mark.xfail(
    reason="Known intermittent — JIRA-789",
    strict=False  # False = unexpected pass is OK
)
def test_flaky_network_call(): ...

# Run with: pytest -m "not flaky"
@pytest.mark.flaky
def test_third_party_integration(): ...
```

### 4.2 Custom Markers + pytest.ini

```ini
# pytest.ini
[pytest]
markers =
    smoke: Fast sanity check tests
    regression: Full regression suite
    api: API-layer tests only
    ui: UI/browser tests
    slow: Tests taking > 10 seconds
    cisco: Cisco-specific CAFY tests
```

```python
@pytest.mark.smoke
@pytest.mark.api
def test_health_endpoint(api_client):
    resp = api_client.get("/health")
    assert resp.status_code == 200

# CI: run only smoke tests
# $ pytest -m "smoke and not slow"
# $ pytest -m "api and not ui"
# $ pytest -m "regression" --tb=short -q
```

### 4.3 Parametrize — The Full Power

```python
# Basic — single param
@pytest.mark.parametrize("status_code", [200, 201, 204])
def test_success_responses(status_code):
    assert is_success(status_code)

# Multiple params with IDs
@pytest.mark.parametrize("username,password,expected", [
    ("admin", "secret", "success"),
    ("user",  "wrong",  "failure"),
    ("",       "",       "failure"),
], ids=["valid_admin", "wrong_password", "empty_creds"])
def test_login(username, password, expected):
    assert login(username, password) == expected

# Stacked parametrize — cartesian product (3 × 2 = 6 combos)
@pytest.mark.parametrize("role", ["admin", "viewer", "editor"])
@pytest.mark.parametrize("env", ["staging", "prod"])
def test_permissions_matrix(role, env):
    perms = get_permissions(env, role)
    assert perms is not None

# pytest.param with marks per test case
@pytest.mark.parametrize("input,expected", [
    ("valid@email.com", True),
    ("no-at-sign", False),
    pytest.param("edge@case", True, marks=pytest.mark.xfail),
])
def test_email_validation(input, expected):
    assert validate_email(input) == expected
```

### 🏋️ Exercise

**Build a Parametrized Test Suite** *(Medium)*

- Register `smoke`, `regression`, and `api` markers in `pytest.ini`
- Write a parametrized test for `classify_status(code)` returning `"success"`, `"redirect"`, `"client_error"`, or `"server_error"`
- Use `pytest.param(..., marks=pytest.mark.xfail)` for edge cases
- Run with `-m "smoke"` and verify only smoke tests run

### 🧠 Quiz

|Q|Question                                                                         |Answer                         |
|-|---------------------------------------------------------------------------------|-------------------------------|
|1|Two stacked `@pytest.mark.parametrize` with 3 and 2 values — how many test cases?|**6** (3 × 2 cartesian product)|

-----

## Module 05 — REST API Testing

> Build a professional API test layer using requests, jsonschema, and custom response models. Go beyond status code assertions.

### 5.1 requests Session & Base Client

```python
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

class APIClient:
    def __init__(self, base_url: str, token: str, timeout: int = 30):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        })
        # Retry on 429, 502, 503 with exponential backoff
        retry = Retry(total=3, backoff_factor=1,
                      status_forcelist=[429, 502, 503])
        adapter = HTTPAdapter(max_retries=retry)
        self.session.mount("https://", adapter)

    def get(self, endpoint: str, **kwargs) -> requests.Response:
        return self.session.get(
            f"{self.base_url}{endpoint}", timeout=self.timeout, **kwargs
        )

    def post(self, endpoint: str, payload: dict, **kwargs):
        return self.session.post(
            f"{self.base_url}{endpoint}",
            json=payload, timeout=self.timeout, **kwargs
        )
```

### 5.2 The 5-Layer Assertion Pattern

```python
import jsonschema

USER_SCHEMA = {
    "type": "object",
    "required": ["id", "username", "email"],
    "properties": {
        "id":       {"type": "integer"},
        "username": {"type": "string", "minLength": 3},
        "email":    {"type": "string", "format": "email"},
    }
}

def test_get_user(api_client):
    resp = api_client.get("/users/1")

    # 1. Status
    assert resp.status_code == 200, f"Expected 200, got {resp.status_code}"

    # 2. Response time SLA
    assert resp.elapsed.total_seconds() < 2.0, "Response too slow"

    # 3. Content-Type
    assert "application/json" in resp.headers["Content-Type"]

    # 4. Schema validation
    data = resp.json()
    jsonschema.validate(instance=data, schema=USER_SCHEMA)

    # 5. Business logic assertions
    assert data["username"] != ""
    assert "@" in data["email"]
```

> **The 5 layers:** Status → Latency → Headers → Schema → Business Logic.
> At 3.5 YOE, your tests should cover all 5 for critical endpoints.

### 🏋️ Exercise

**Full API Test Suite** *(Hard)*

- Create an `APIClient` fixture with session scope
- Test `GET /users` — schema validation + all 5 assertion layers
- Test `POST /posts` — verify 201, Location header, response body
- Test `DELETE /posts/1` — verify 200, then 404 on second delete
- Add `@pytest.mark.api` marker on all tests

> Try it live with [JSONPlaceholder](https://jsonplaceholder.typicode.com) — a free fake REST API.

### 🧠 Quiz

|Q|Question                                                            |Answer                                                                     |
|-|--------------------------------------------------------------------|---------------------------------------------------------------------------|
|1|Why use `requests.Session()` instead of standalone `requests.get()`?|Session reuses TCP connections and persists headers/cookies across requests|

-----

## Module 06 — Mocking & Patching

> `unittest.mock` and `pytest-mock` let you isolate units under test. Master `MagicMock`, `patch`, `side_effect`, and call assertions.

### 6.1 MagicMock — Core Concepts

```python
from unittest.mock import MagicMock, patch, call

# MagicMock auto-creates any attribute/method you access
mock_db = MagicMock()
mock_db.get_user.return_value = {"id": 1, "name": "Alice"}

result = mock_db.get_user(1)
assert result["name"] == "Alice"
mock_db.get_user.assert_called_once_with(1)

# side_effect — raise exceptions or cycle through values
mock_db.get_user.side_effect = ConnectionError("DB is down")
mock_db.get_user.side_effect = ["first", "second", StopIteration]

# Spy on call history
mock_service = MagicMock()
mock_service("a"); mock_service("b")
assert mock_service.call_count == 2
assert mock_service.call_args_list == [call("a"), call("b")]
```

### 6.2 patch — The Golden Rule

> **Patch where the object is USED, not where it’s defined.** This is the #1 mistake with mocking.

```python
# myapp/services.py does: import requests
# Patch it at the USAGE site, not at requests module:
@patch("myapp.services.requests.get")  # ✅ correct
# @patch("requests.get")               # ❌ won't intercept
def test_fetch_data(mock_get):
    mock_get.return_value.status_code = 200
    mock_get.return_value.json.return_value = {"status": "ok"}

    result = services.fetch_data()
    assert result["status"] == "ok"
    mock_get.assert_called_once()

# As context manager
def test_with_context():
    with patch("myapp.services.send_email") as mock_email:
        services.register_user("alice@test.com")
        mock_email.assert_called_once_with(to="alice@test.com")
```

### 6.3 pytest-mock — mocker fixture

```python
# pytest-mock's mocker fixture auto-cleans up after each test
def test_send_notification(mocker):
    mock_send = mocker.patch("notifications.send_sms")
    mock_send.return_value = {"status": "sent"}

    notify_user(user_id=1, message="Test")

    mock_send.assert_called_once_with(
        to="+1234567890", body="Test"
    )

# mocker.spy — real function but records calls
def test_spy_on_method(mocker):
    spy = mocker.spy(MyService, "process")
    service = MyService()
    service.process("input")

    spy.assert_called_once_with("input")
    # Unlike a mock, the real process() still ran!
```

### 🏋️ Exercise

**Mock External Payments Service** *(Hard)*

- Test happy path: payment succeeds → order status = `"confirmed"`
- Test failure: `side_effect=PaymentGatewayError` → order status = `"failed"`
- Test retry: first call fails, second succeeds — verify called twice
- Use `mocker.patch` (pytest-mock) not the decorator form

### 🧠 Quiz

|Q|Question                                                              |Answer                                                              |
|-|----------------------------------------------------------------------|--------------------------------------------------------------------|
|1|Module does `from requests import get`. What’s the correct patch path?|`patch("myapp.module.get")` — patch the name in the target namespace|

-----

## Module 07 — Page Object, AAA & BDD

> Scalable test architecture. POM for UI, AAA for structure, BDD for collaboration.

### 7.1 AAA Pattern — Arrange, Act, Assert

Every test should have exactly three sections. This makes tests scannable at 3am when something’s broken in production.

```python
def test_user_creation_returns_id(api_client):
    # ARRANGE — set up everything needed for the test
    payload = {"username": "new_user", "email": "new@test.com"}

    # ACT — single action under test
    response = api_client.post("/users", payload)

    # ASSERT — verify outcomes, not implementation
    assert response.status_code == 201
    assert "id" in response.json()
    assert response.json()["username"] == payload["username"]
```

> **One behavior per test.** If you assert 8 things and the 5th fails, you don’t know if 6–8 pass.

### 7.2 BDD with pytest-bdd

```gherkin
# features/login.feature
Feature: User Authentication

  Scenario: Successful login with valid credentials
    Given the user is on the login page
    When they enter username "alice" and password "secret"
    Then they should be redirected to the dashboard
    And the welcome message should display "Hello, Alice"

  Scenario Outline: Failed login
    Given the user is on the login page
    When they enter username "<username>" and password "<password>"
    Then they should see error "<error_msg>"

    Examples:
      | username | password | error_msg            |
      | alice    | wrong    | Invalid credentials  |
      |          | secret   | Username is required |
```

```python
# step_definitions/test_login.py
from pytest_bdd import given, when, then, parsers

@given("the user is on the login page")
def user_on_login_page(login_page):
    login_page.load()
    assert login_page.is_loaded()

@when(parsers.parse('they enter username "{user}" and password "{pwd}"'))
def enter_credentials(login_page, user, pwd):
    login_page.enter_username(user)
    login_page.enter_password(pwd)
    login_page.submit()

@then("they should be redirected to the dashboard")
def verify_redirect(driver):
    assert "/dashboard" in driver.current_url
```

### 🏋️ Exercise

**BDD Feature File** *(Medium)*

- Feature: Shopping cart total calculation
- Scenario Outline with 3 examples: normal, discount, empty cart
- Use `@given/@when/@then` with `parsers.parse` for dynamic values
- Connect step definitions to a mock `Cart` class using fixtures

### 🧠 Quiz

|Q|Question                               |Answer                                      |
|-|---------------------------------------|--------------------------------------------|
|1|Main rule for the “Act” section in AAA?|Exactly one action — the behavior under test|

-----

## Module 08 — Data-Driven Testing

> Drive tests from CSV, JSON, and Excel files. Combine parametrize with external data sources.

### 8.1 CSV & JSON as Test Data Sources

```python
import json, csv
from pathlib import Path

def load_json_cases(filename: str) -> list:
    path = Path(__file__).parent / "data" / filename
    with open(path) as f:
        return json.load(f)

def load_csv_cases(filename: str) -> list[tuple]:
    path = Path(__file__).parent / "data" / filename
    with open(path) as f:
        reader = csv.DictReader(f)
        return [(r["input"], r["expected"]) for r in reader]

# Drive parametrize from JSON
@pytest.mark.parametrize("case", load_json_cases("login_cases.json"))
def test_login_variants(api_client, case):
    resp = api_client.post("/login", {
        "user": case["username"],
        "pass": case["password"]
    })
    assert resp.status_code == case["expected_status"]
```

### 8.2 Sample JSON test data file

```json
[
  {
    "description": "valid_admin_login",
    "username": "admin",
    "password": "secret",
    "expected_status": 200
  },
  {
    "description": "wrong_password",
    "username": "alice",
    "password": "wrongpass",
    "expected_status": 401
  },
  {
    "description": "empty_credentials",
    "username": "",
    "password": "",
    "expected_status": 400
  }
]
```

> **Always use `Path(__file__).parent / "data"`** — never hardcode absolute paths. This works regardless of where pytest is run from.

### 🏋️ Exercise

**JSON-Driven API Tests** *(Medium)*

- Create `tests/data/api_cases.json` with 5 login test cases
- Write a fixture that loads this JSON and parametrizes dynamically
- Include negative cases: wrong password, missing fields, locked account
- Generate test IDs from the JSON `"description"` field

### 🧠 Quiz

|Q|Question                                                   |Answer                                                                             |
|-|-----------------------------------------------------------|-----------------------------------------------------------------------------------|
|1|Why use `Path(__file__).parent` instead of hardcoded paths?|The path remains valid regardless of the current working directory when pytest runs|

-----

## Module 09 — CI/CD Integration

> Run your pytest suite in GitHub Actions and Jenkins. Handle parallel execution, artifacts, and failure notifications.

### 9.1 GitHub Actions Workflow

```yaml
# .github/workflows/tests.yml
name: Test Suite

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  schedule:
    - cron: "0 6 * * *"    # daily 6am UTC

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ["3.10", "3.11", "3.12"]

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
          cache: "pip"

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run smoke tests
        run: pytest -m smoke --tb=short -q

      - name: Run full suite
        run: |
          pytest tests/ \
            --tb=short \
            --junitxml=reports/junit.xml \
            --html=reports/report.html \
            -n auto                    # parallel with pytest-xdist

      - name: Upload test reports
        if: always()                   # upload even on failure
        uses: actions/upload-artifact@v4
        with:
          name: test-reports
          path: reports/
```

### 9.2 Parallel Execution with pytest-xdist

```bash
# -n auto — uses all available CPUs
pytest tests/ -n auto

# -n 4 — exactly 4 workers
pytest tests/ -n 4

# --dist=loadfile — tests in same file run in same worker
# Prevents test ordering issues within a module
pytest tests/ -n 4 --dist=loadfile
```

> **Tests must be independent for parallel execution.** No shared mutable state. Use `tmp_path` fixture (not a shared directory) for file operations.

### 9.3 Jenkins Pipeline (Declarative)

```groovy
pipeline {
    agent any
    stages {
        stage('Install') {
            steps {
                sh 'pip install -r requirements.txt'
            }
        }
        stage('Smoke Tests') {
            steps {
                sh 'pytest -m smoke --tb=short -q'
            }
        }
        stage('Full Suite') {
            steps {
                sh 'pytest tests/ -n auto --junitxml=reports/junit.xml'
            }
        }
    }
    post {
        always {
            junit 'reports/junit.xml'
            archiveArtifacts artifacts: 'reports/**', fingerprint: true
        }
        failure {
            slackSend channel: '#test-alerts', message: "Tests FAILED: ${env.BUILD_URL}"
        }
    }
}
```

### 🏋️ Exercise

**GitHub Actions Pipeline** *(Hard)*

- Matrix strategy: Python 3.10, 3.11, 3.12
- Stage 1: smoke tests (fast feedback)
- Stage 2: full suite with `-n auto` parallel execution
- Upload Allure results as artifacts on both success and failure
- Add a Slack notification step on failure using a webhook secret

### 🧠 Quiz

|Q|Question                                               |Answer                                            |
|-|-------------------------------------------------------|--------------------------------------------------|
|1|What does `if: always()` do on an upload-artifact step?|Runs the step even when previous steps have failed|

-----

## Module 10 — Test Reporting

> Allure Framework, pytest-html, and JUnit XML. Generate reports your team, PM, and CI dashboard can all read.

### 10.1 Allure Framework Setup

```bash
pip install allure-pytest

# Run and generate results
pytest tests/ --alluredir=allure-results

# Generate and serve HTML report
allure generate allure-results -o allure-report --clean
allure open allure-report
```

### 10.2 Allure Annotations

```python
import allure

@allure.feature("User Management")
@allure.story("Create User")
@allure.severity(allure.severity_level.CRITICAL)
def test_create_user(api_client):
    with allure.step("Send POST /users request"):
        resp = api_client.post("/users", {"name": "Alice"})

    with allure.step("Verify 201 Created"):
        assert resp.status_code == 201

    # Attach response for debugging in report
    allure.attach(
        resp.text,
        name="API Response",
        attachment_type=allure.attachment_type.JSON
    )
```

### 10.3 pytest-html

```bash
pip install pytest-html

pytest tests/ --html=report.html --self-contained-html
```

### 10.4 JUnit XML (for CI integration)

```bash
# Consumed by Jenkins, GitHub Actions, GitLab CI
pytest tests/ --junitxml=reports/junit.xml
```

### 🏋️ Exercise

**Allure-Annotated Test Suite** *(Medium)*

- Add `@allure.feature`, `@allure.story`, `@allure.severity` to all tests
- Wrap each logical step in `with allure.step()`
- Attach API request payload and response as JSON attachments
- On test failure, capture response body
- Generate the Allure report and inspect the timeline view

### 🧠 Quiz

|Q|Question                                      |Answer                                                                               |
|-|----------------------------------------------|-------------------------------------------------------------------------------------|
|1|Benefit of `with allure.step()` inside a test?|Failed tests show exactly which step failed with a human-readable label in the report|

-----

## Module 11 — CAFY Framework (Cisco)

> Cisco’s CAFY (Cisco Automated Functional tY) framework patterns and how they map to standard pytest concepts.

### 11.1 CAFY Architecture Overview

CAFY is Cisco’s internal test automation framework built on Python. Key components:

- **Testbed YAML files** — device topology and connection info
- **Trigger/Verification structure** — similar to AAA pattern
- **pyATS** (`ats`) — the underlying test infrastructure
- **XPRESSO** — Cisco’s CI/CD platform

### 11.2 Testbed YAML

```yaml
testbed:
  name: lab_topology_1

devices:
  router-1:
    type: router
    os: iosxe
    connections:
      defaults:
        class: unicon.Unicon
      a:
        protocol: telnet
        ip: 10.1.1.1
        port: 2001
```

### 11.3 Trigger/Verification Pattern

```python
from ats.aetest import Testcase, setup, test, cleanup

class TriggerShutNoShutBgp(Testcase):
    """Trigger: Shut BGP neighbor, verify recovery."""

    @setup
    def setup(self, testbed):
        # Equivalent to pytest fixture setup
        self.device = testbed.devices["router-1"]
        self.device.connect()
        # Snapshot initial BGP state
        self.initial_state = self.device.parse("show bgp summary")

    @test
    def shut_bgp(self):
        # ACT
        self.device.configure("router bgp 65001\n neighbor 10.0.0.1 shutdown")
        # ASSERT
        state = self.device.parse("show bgp summary")
        assert state["neighbors"]["10.0.0.1"]["state"] == "Idle"

    @cleanup
    def restore(self):
        # Equivalent to pytest yield teardown
        self.device.configure("router bgp 65001\n no neighbor 10.0.0.1 shutdown")
        self.device.disconnect()
```

### 11.4 CAFY → Pytest Mapping

|CAFY Concept        |Pytest Equivalent                                      |
|--------------------|-------------------------------------------------------|
|`Testcase` class    |Test class or module                                   |
|`@setup` method     |`@pytest.fixture` (function scope) — setup before yield|
|`@test` method      |`def test_*()` function                                |
|`@cleanup` method   |`yield` fixture teardown                               |
|`testbed.yaml`      |`conftest.py` fixtures providing connections           |
|`aetest.parameters` |`@pytest.mark.parametrize`                             |
|Trigger library     |Page Object / Service class                            |
|Verification library|Custom assertion helpers                               |
|XPRESSO pipeline    |GitHub Actions / Jenkins                               |
|Job file (.yaml)    |`pytest.ini` + `conftest.py`                           |


> **Interview tip:** *“In CAFY, I used trigger/verification architecture with testbed YAML for topology. In pytest, I apply the same pattern using fixtures for environment setup and parametrize for cross-device test variants.”* — this shows you understand both the concept AND the implementation.

### 🏋️ Exercise

**Port CAFY Test to Pytest** *(Hard)*

- Convert CAFY `@setup` to a session-scoped fixture in `conftest.py`
- Convert `@cleanup` to yield-based teardown
- Convert CAFY parameters to `@pytest.mark.parametrize`
- Replace testbed YAML parsing with a fixture reading a YAML config file
- Add Allure annotations with device info and test steps

### 🧠 Quiz

|Q|Question                                            |Answer                                                          |
|-|----------------------------------------------------|----------------------------------------------------------------|
|1|CAFY `@setup` is equivalent to which pytest concept?|A pytest fixture with yield — setup before yield, teardown after|

-----

## Quick Reference Cheatsheet

### Pytest CLI Commands

```bash
# Run by marker
pytest -m smoke
pytest -m "api and not slow"
pytest -m "regression" --tb=short -q

# Run specific file/test
pytest tests/test_users.py
pytest tests/test_users.py::test_create_user
pytest tests/test_users.py::TestUsers::test_delete

# Output options
pytest -v           # verbose
pytest -s           # show print statements
pytest --tb=short   # shorter tracebacks
pytest -x           # stop on first failure
pytest --lf         # rerun last failed only
pytest --co         # collect only (dry run)

# Parallel
pytest -n auto
pytest -n 4 --dist=loadfile

# Reporting
pytest --junitxml=reports/junit.xml
pytest --html=reports/report.html --self-contained-html
pytest --alluredir=allure-results
```

### Fixture Scope Decision Tree

```
Does the resource cost a lot to set up? (DB connection, auth token)
├── YES → Use session or module scope
│   ├── Shared across ALL tests? → session
│   └── Shared within a file?   → module
└── NO → Use function scope (default)
    └── Apply to all tests automatically? → autouse=True
```

### Mock Assertion Methods

```python
mock.assert_called()                    # called at least once
mock.assert_called_once()              # called exactly once
mock.assert_called_with(arg1, arg2)    # last call had these args
mock.assert_called_once_with(arg1)     # called once with these args
mock.assert_any_call(arg)              # any call had this arg
mock.assert_not_called()               # never called
mock.call_count                        # number of calls
mock.call_args                         # args of last call
mock.call_args_list                    # list of all call args
```

### Common pytest Plugins

|Plugin                |Install                           |Use                    |
|----------------------|----------------------------------|-----------------------|
|`pytest-xdist`        |`pip install pytest-xdist`        |Parallel test execution|
|`pytest-mock`         |`pip install pytest-mock`         |`mocker` fixture       |
|`pytest-html`         |`pip install pytest-html`         |HTML reports           |
|`allure-pytest`       |`pip install allure-pytest`       |Allure reports         |
|`pytest-cov`          |`pip install pytest-cov`          |Code coverage          |
|`responses`           |`pip install responses`           |Mock HTTP requests     |
|`pytest-bdd`          |`pip install pytest-bdd`          |BDD / Gherkin          |
|`faker`               |`pip install faker`               |Generate fake test data|
|`pytest-rerunfailures`|`pip install pytest-rerunfailures`|Auto-retry flaky tests |

-----

*Generated for SDET Interview Prep · 3.5 YOE Python & Pytest Path*