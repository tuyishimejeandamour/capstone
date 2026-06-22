from __future__ import annotations

from ranga_train.evaluate import evaluate_model
from ranga_train.data import prepare_eval_records
from tests.conftest import FIXTURES


def test_evaluate_model_on_fixture_with_stub_generator():
    records = prepare_eval_records(
        FIXTURES / "sample_eval.jsonl",
        FIXTURES / "ranga_tools.json",
    )

    def generator(**kwargs):
        return "<start_function_call>call:getCurrentLocation{}<end_function_call>"

    report = evaluate_model(
        model_label="stub",
        eval_records=records,
        system_prompt="Follow the Ranga tool pipeline.",
        generate_fn=generator,
        max_cases=2,
    )

    assert report.num_cases == 2
    assert 0.0 <= report.first_tool_accuracy <= 1.0
    assert report.mean_completion_rate > 0.0
