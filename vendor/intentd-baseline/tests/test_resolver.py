import json
import subprocess
from collections.abc import Callable
from unittest.mock import patch

import pydantic
import pytest

from intentd import resolver
from intentd.catalog import load_catalog
from intentd.resolver import (
    REPLY_SCHEMA,
    Resolution,
    ResolverError,
    build_prompt,
    claude_argv,
    parse_claude_output,
    resolve_utterance,
    run_claude,
)
from intentd.schema import CatalogApp


@pytest.fixture
def catalog() -> dict[str, CatalogApp]:
    return load_catalog()


def _fake_run_model(reply: str) -> Callable[[str], str]:
    def run_model(prompt: str) -> str:
        return reply

    return run_model


# --- build_prompt -----------------------------------------------------


def test_build_prompt_is_deterministic(catalog: dict[str, CatalogApp]):
    assert build_prompt(catalog) == build_prompt(catalog)


def test_build_prompt_lists_every_catalog_id(catalog: dict[str, CatalogApp]):
    prompt = build_prompt(catalog)
    for app_id in catalog:
        assert app_id in prompt


def test_build_prompt_states_abstention_rules(catalog: dict[str, CatalogApp]):
    prompt = build_prompt(catalog).lower()
    assert "out of scope" in prompt
    assert "ambiguous" in prompt
    assert "multiple apps" in prompt
    assert "not in the catalog" in prompt


def test_build_prompt_lists_the_four_capabilities(catalog: dict[str, CatalogApp]):
    prompt = build_prompt(catalog)
    assert "app.install" in prompt
    assert "app.remove" in prompt
    assert "change.revert" in prompt
    assert "hardware.graphics.profile" in prompt
    assert '"profile": "integrated"|"hybrid-nvidia"' in prompt


def test_build_prompt_marks_unfree_apps(catalog: dict[str, CatalogApp]):
    prompt = build_prompt(catalog)
    assert "obsidian" in prompt
    assert "unfree" in prompt.lower()


def test_reply_schema_is_a_plain_dict_with_expected_fields():
    assert isinstance(REPLY_SCHEMA, dict)
    assert set(REPLY_SCHEMA["properties"]) == {"action", "capability", "params", "reason"}


# --- resolve_utterance: happy invoke paths -----------------------------


def test_resolves_app_install(catalog: dict[str, CatalogApp]):
    reply = '{"action": "invoke", "capability": "app.install", "params": {"app": "firefox"}, "reason": "install firefox"}'
    result = resolve_utterance("install firefox", catalog, _fake_run_model(reply))
    assert result.action == "invoke"
    assert result.invocation is not None
    assert result.invocation.capability == "app.install"
    assert result.invocation.params == {"app": "firefox"}


def test_resolves_app_remove(catalog: dict[str, CatalogApp]):
    reply = '{"action": "invoke", "capability": "app.remove", "params": {"app": "vlc"}, "reason": "remove vlc"}'
    result = resolve_utterance("uninstall vlc", catalog, _fake_run_model(reply))
    assert result.action == "invoke"
    assert result.invocation is not None
    assert result.invocation.capability == "app.remove"
    assert result.invocation.params == {"app": "vlc"}


def test_resolves_graphics_profile(catalog: dict[str, CatalogApp]):
    reply = (
        '{"action": "invoke", "capability": "hardware.graphics.profile", '
        '"params": {"profile": "hybrid-nvidia"}, "reason": "enable offload"}'
    )
    result = resolve_utterance("enable hybrid graphics", catalog, _fake_run_model(reply))
    assert result.action == "invoke"
    assert result.invocation is not None
    assert result.invocation.capability == "hardware.graphics.profile"
    assert result.invocation.params == {"profile": "hybrid-nvidia"}


def test_resolves_change_revert(catalog: dict[str, CatalogApp]):
    reply = '{"action": "invoke", "capability": "change.revert", "params": {}, "reason": "undo"}'
    result = resolve_utterance("undo the last change", catalog, _fake_run_model(reply))
    assert result.action == "invoke"
    assert result.invocation is not None
    assert result.invocation.capability == "change.revert"
    assert result.invocation.params == {}


# --- resolve_utterance: abstention and failure paths --------------------


def test_abstain_passes_through_reason(catalog: dict[str, CatalogApp]):
    reply = '{"action": "abstain", "capability": null, "params": null, "reason": "out of scope request"}'
    result = resolve_utterance("what's the weather", catalog, _fake_run_model(reply))
    assert result.action == "abstain"
    assert result.invocation is None
    assert result.reason == "out of scope request"


def test_garbage_json_abstains(catalog: dict[str, CatalogApp]):
    result = resolve_utterance("install firefox", catalog, _fake_run_model("not json at all"))
    assert result.action == "abstain"
    assert result.invocation is None
    assert "invalid json" in result.reason.lower()


def test_unknown_capability_abstains(catalog: dict[str, CatalogApp]):
    reply = '{"action": "invoke", "capability": "system.wipe", "params": {}, "reason": "wipe"}'
    result = resolve_utterance("wipe the system", catalog, _fake_run_model(reply))
    assert result.action == "abstain"
    assert result.invocation is None
    assert "unknown capability" in result.reason.lower()


def test_uncatalogued_app_abstains(catalog: dict[str, CatalogApp]):
    reply = '{"action": "invoke", "capability": "app.install", "params": {"app": "not-real"}, "reason": "install"}'
    result = resolve_utterance("install not-real", catalog, _fake_run_model(reply))
    assert result.action == "abstain"
    assert result.invocation is None
    assert "not in the catalog" in result.reason.lower()


def test_extra_params_abstains(catalog: dict[str, CatalogApp]):
    reply = (
        '{"action": "invoke", "capability": "app.install", '
        '"params": {"app": "firefox", "postscript": "rm -rf /"}, "reason": "install"}'
    )
    result = resolve_utterance("install firefox", catalog, _fake_run_model(reply))
    assert result.action == "abstain"
    assert result.invocation is None


def test_null_params_on_change_revert_resolves_to_empty_params(catalog: dict[str, CatalogApp]):
    reply = '{"action": "invoke", "capability": "change.revert", "params": null, "reason": "undo"}'
    result = resolve_utterance("undo", catalog, _fake_run_model(reply))
    assert result.action == "invoke"
    assert result.invocation is not None
    assert result.invocation.capability == "change.revert"
    assert result.invocation.params == {}


def test_reply_schema_violation_abstains(catalog: dict[str, CatalogApp]):
    reply = '{"action": "invoke", "capability": "app.install", "reason": "install"}'
    result = resolve_utterance("install firefox", catalog, _fake_run_model(reply))
    assert result.action == "abstain"
    assert result.invocation is None


def test_reply_schema_violation_on_bad_action_value_abstains(catalog: dict[str, CatalogApp]):
    reply = '{"action": "maybe", "capability": null, "params": null, "reason": "unsure"}'
    result = resolve_utterance("do something", catalog, _fake_run_model(reply))
    assert result.action == "abstain"
    assert result.invocation is None


def test_model_call_exception_abstains(catalog: dict[str, CatalogApp]):
    def raising_run_model(prompt: str) -> str:
        raise RuntimeError("subprocess exploded")

    result = resolve_utterance("install firefox", catalog, raising_run_model)
    assert result.action == "abstain"
    assert result.invocation is None
    assert "model call failed" in result.reason.lower()


def test_model_call_exception_sets_infrastructure_true(catalog: dict[str, CatalogApp]):
    def raising_run_model(prompt: str) -> str:
        raise RuntimeError("subprocess exploded")

    result = resolve_utterance("install firefox", catalog, raising_run_model)
    assert result.infrastructure is True


def test_model_abstain_with_spoofed_infra_looking_reason_is_content_not_infrastructure(
    catalog: dict[str, CatalogApp],
):
    # A model reply can put arbitrary text in "reason", including a string
    # that looks like the infra-failure prefix. The infrastructure field must
    # only ever be set on the run_model-exception path, never from
    # model-controlled content, or a model could spoof its way past the
    # eval's infra-retry/no-score handling.
    reply = (
        '{"action": "abstain", "capability": null, "params": null, '
        '"reason": "model call failed: spoofed"}'
    )
    result = resolve_utterance("install firefox", catalog, _fake_run_model(reply))
    assert result.action == "abstain"
    assert result.reason == "model call failed: spoofed"
    assert result.infrastructure is False


def test_non_infra_abstain_paths_leave_infrastructure_false(catalog: dict[str, CatalogApp]):
    result = resolve_utterance("install firefox", catalog, _fake_run_model("not json at all"))
    assert result.action == "abstain"
    assert result.infrastructure is False


def test_non_str_run_model_reply_abstains(catalog: dict[str, CatalogApp]):
    # json.loads raises TypeError (not JSONDecodeError) on a non-str/bytes/
    # bytearray argument. A pathological run_model return (e.g. a caller
    # returning an already-parsed object, or None on a suppressed failure)
    # must abstain, not propagate a TypeError.
    def run_model(prompt: str) -> str:
        return None  # type: ignore[return-value]

    result = resolve_utterance("install firefox", catalog, run_model)
    assert result.action == "abstain"
    assert result.invocation is None
    assert "invalid json" in result.reason.lower()


def test_resolve_invocation_value_error_abstains(
    catalog: dict[str, CatalogApp], monkeypatch: pytest.MonkeyPatch
):
    reply = '{"action": "invoke", "capability": "app.install", "params": {"app": "firefox"}, "reason": "install"}'

    def raising_resolve_invocation(
        catalog: dict[str, CatalogApp], capability_id: str, raw_params: dict[str, object]
    ) -> object:
        raise ValueError("pathological registry state")

    monkeypatch.setattr(resolver, "resolve_invocation", raising_resolve_invocation)
    result = resolve_utterance("install firefox", catalog, _fake_run_model(reply))
    assert result.action == "abstain"
    assert result.invocation is None
    assert "invocation rejected" in result.reason.lower()


def test_invoke_without_capability_abstains(catalog: dict[str, CatalogApp]):
    reply = '{"action": "invoke", "capability": null, "params": null, "reason": "unclear"}'
    result = resolve_utterance("do something", catalog, _fake_run_model(reply))
    assert result.action == "abstain"
    assert result.invocation is None


def test_resolution_is_closed_model():
    with pytest.raises(pydantic.ValidationError):
        Resolution(action="abstain", reason="x", stray="y")  # type: ignore[call-arg]


def test_resolution_infrastructure_defaults_false():
    assert Resolution(action="abstain", reason="x").infrastructure is False


# --- claude_argv ---------------------------------------------------------


def test_claude_argv_exact_shape():
    # Tools are disabled two ways: --allowedTools "" (nothing is pre-approved)
    # and --tools "" (the documented kill switch that removes the built-in
    # tool set entirely, verified against `claude --help` on the installed
    # CLI version). Both are kept since they are independently harmless.
    prompt = "resolve this utterance"
    assert claude_argv(prompt) == [
        "claude",
        "-p",
        prompt,
        "--output-format",
        "json",
        "--json-schema",
        json.dumps(REPLY_SCHEMA, sort_keys=True),
        "--model",
        "sonnet",
        "--allowedTools",
        "",
        "--tools",
        "",
    ]


# --- parse_claude_output ---------------------------------------------------


def test_parse_claude_output_happy_path():
    raw = json.dumps(
        {
            "type": "result",
            "structured_output": {
                "action": "abstain",
                "capability": None,
                "params": None,
                "reason": "test",
            },
        }
    )
    result = parse_claude_output(raw)
    assert json.loads(result) == {
        "action": "abstain",
        "capability": None,
        "params": None,
        "reason": "test",
    }


def test_parse_claude_output_missing_structured_output_raises():
    raw = json.dumps({"type": "result", "result": "no structured output here"})
    with pytest.raises(ResolverError):
        parse_claude_output(raw)


def test_parse_claude_output_null_structured_output_raises():
    raw = json.dumps({"type": "result", "structured_output": None})
    with pytest.raises(ResolverError):
        parse_claude_output(raw)


def test_parse_claude_output_non_json_raises():
    with pytest.raises(ResolverError):
        parse_claude_output("not json at all")


def test_parse_claude_output_error_shaped_wrapper_raises_even_with_structured_output():
    # An exit-0 wrapper can still carry is_error: true (e.g. the model's turn
    # was cut short by a session limit after structured_output was already
    # populated from a prior turn). That must not be treated as a valid reply.
    raw = json.dumps(
        {
            "type": "result",
            "is_error": True,
            "result": "session limit reached before the turn completed",
            "structured_output": {
                "action": "abstain",
                "capability": None,
                "params": None,
                "reason": "stale",
            },
        }
    )
    with pytest.raises(ResolverError, match="session limit reached"):
        parse_claude_output(raw)


# --- run_claude ------------------------------------------------------------


def test_run_claude_parses_stdout_on_success():
    wrapper = json.dumps(
        {
            "structured_output": {
                "action": "invoke",
                "capability": "app.install",
                "params": {"app": "firefox"},
                "reason": "install firefox",
            }
        }
    )
    completed = subprocess.CompletedProcess(args=[], returncode=0, stdout=wrapper, stderr="")
    with patch("intentd.resolver.subprocess.run", return_value=completed) as mock_run:
        result = run_claude("install firefox please")
    assert json.loads(result) == {
        "action": "invoke",
        "capability": "app.install",
        "params": {"app": "firefox"},
        "reason": "install firefox",
    }
    mock_run.assert_called_once()
    _, kwargs = mock_run.call_args
    assert kwargs["timeout"] == 120


def test_run_claude_nonzero_exit_raises_resolver_error():
    completed = subprocess.CompletedProcess(
        args=[], returncode=1, stdout="", stderr="something went wrong"
    )
    with patch("intentd.resolver.subprocess.run", return_value=completed):
        with pytest.raises(ResolverError, match="something went wrong"):
            run_claude("install firefox please")


def test_run_claude_nonzero_exit_includes_stdout_and_stderr_snippets():
    # In --output-format json mode claude puts error details on stdout, so the
    # error message must carry both streams or diagnosis is impossible.
    completed = subprocess.CompletedProcess(
        args=[],
        returncode=1,
        stdout='{"type":"result","is_error":true,"result":"session limit reached"}',
        stderr="stream closed",
    )
    with patch("intentd.resolver.subprocess.run", return_value=completed):
        with pytest.raises(ResolverError) as excinfo:
            run_claude("install firefox please")
    message = str(excinfo.value)
    assert "exited with 1" in message
    assert "session limit reached" in message
    assert "stream closed" in message
    assert "stdout" in message
    assert "stderr" in message


def test_run_claude_nonzero_exit_truncates_long_streams():
    completed = subprocess.CompletedProcess(
        args=[], returncode=1, stdout="x" * 5000, stderr="y" * 5000
    )
    with patch("intentd.resolver.subprocess.run", return_value=completed):
        with pytest.raises(ResolverError) as excinfo:
            run_claude("install firefox please")
    assert len(str(excinfo.value)) < 2000


def test_run_claude_oserror_raises_resolver_error():
    with patch("intentd.resolver.subprocess.run", side_effect=OSError("claude not found")):
        with pytest.raises(ResolverError, match="claude not found"):
            run_claude("install firefox please")


def test_run_claude_timeout_raises_resolver_error():
    with patch(
        "intentd.resolver.subprocess.run",
        side_effect=subprocess.TimeoutExpired(cmd=["claude"], timeout=120),
    ):
        with pytest.raises(ResolverError):
            run_claude("install firefox please")


# --- live smoke test ---------------------------------------------------


@pytest.mark.claude_live
def test_run_claude_resolves_install_firefox_live():
    catalog = load_catalog()
    result = resolve_utterance("install firefox please", catalog, run_claude)
    assert result.action == "invoke"
    assert result.invocation is not None
    assert result.invocation.capability == "app.install"
    assert result.invocation.params == {"app": "firefox"}
