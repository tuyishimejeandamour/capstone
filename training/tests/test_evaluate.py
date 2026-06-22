from __future__ import annotations

from ranga_train.evaluate import (
    EvaluationReport,
    aggregate_report,
    evaluate_case,
    first_function_call,
    insurance_argument_matches,
    mock_tool_response,
    parse_function_calls,
    tool_names_from_output,
)


SAMPLE_OUTPUT = (
    "<start_function_call>call:getInsuranceCoverageBlock"
    "{insurance:<escape>RSSB<escape>}<end_function_call>"
)


def test_parse_function_calls():
    calls = parse_function_calls(SAMPLE_OUTPUT)
    assert len(calls) == 1
    assert calls[0]["name"] == "getInsuranceCoverageBlock"
    assert calls[0]["arguments"]["insurance"] == "RSSB"


def test_first_function_call():
    call = first_function_call(SAMPLE_OUTPUT)
    assert call is not None
    assert call["name"] == "getInsuranceCoverageBlock"


def test_tool_names_from_output():
    assert tool_names_from_output(SAMPLE_OUTPUT) == ["getInsuranceCoverageBlock"]


def test_insurance_argument_matches():
    expected = {"name": "getInsuranceCoverageBlock", "arguments": {"insurance": "RSSB"}}
    predicted = {"name": "getInsuranceCoverageBlock", "arguments": {"insurance": "rssb"}}
    assert insurance_argument_matches(expected, predicted) is True


def test_mock_tool_response_shapes():
    location = mock_tool_response("getCurrentLocation")
    assert "lat" in location
    rank = mock_tool_response("rankHospitalsByPriorityAndCost")
    assert "rankedResults" in rank


def test_evaluate_case_perfect_sequence():
    calls = []

    def fake_generate(**kwargs):
        step = len(calls) + 1
        expected = [
            "getCurrentLocation",
            "getInsuranceCoverageBlock",
            "getNearbyHospitals",
            "rankHospitalsByPriorityAndCost",
        ][step - 1]
        calls.append(expected)
        if expected == "getInsuranceCoverageBlock":
            return (
                "<start_function_call>call:getInsuranceCoverageBlock"
                "{insurance:<escape>CBHI<escape>}<end_function_call>"
            )
        return f"<start_function_call>call:{expected}{{}}<end_function_call>"

    result = evaluate_case(
        user_query="Need a clinic",
        expected_tool_calls=[
            {"name": "getCurrentLocation", "arguments": {}},
            {"name": "getInsuranceCoverageBlock", "arguments": {"insurance": "CBHI"}},
            {"name": "getNearbyHospitals", "arguments": {"lat": -1.9695, "lng": 30.1589}},
            {"name": "rankHospitalsByPriorityAndCost", "arguments": {}},
        ],
        expected_pipeline="nearby",
        expected_scheme="CBHI",
        system_prompt="Use tools in order.",
        tools=[],
        generate_fn=fake_generate,
    )

    assert result.tool_order_correct is True
    assert result.pipeline_correct is True
    assert result.completion_rate == 1.0
    assert result.insurance_correct is True


def test_evaluate_case_stops_after_wrong_tool():
    def fake_generate(**kwargs):
        return "<start_function_call>call:getNearbyHospitals{}<end_function_call>"

    result = evaluate_case(
        user_query="Need a clinic",
        expected_tool_calls=[
            {"name": "getCurrentLocation", "arguments": {}},
            {"name": "getInsuranceCoverageBlock", "arguments": {"insurance": "CBHI"}},
        ],
        expected_pipeline="nearby",
        expected_scheme="CBHI",
        system_prompt="Use tools in order.",
        tools=[],
        generate_fn=fake_generate,
    )

    assert result.tool_order_correct is False
    assert result.completion_rate == 0.5


def test_aggregate_report_and_comparison():
    baseline = EvaluationReport(
        model_label="baseline",
        num_cases=2,
        tool_order_accuracy=0.0,
        pipeline_accuracy=0.5,
        first_tool_accuracy=0.5,
        rank_tool_rate=0.0,
        insurance_argument_accuracy=0.0,
        mean_completion_rate=0.25,
    )
    finetuned = EvaluationReport(
        model_label="finetuned",
        num_cases=2,
        tool_order_accuracy=1.0,
        pipeline_accuracy=1.0,
        first_tool_accuracy=1.0,
        rank_tool_rate=1.0,
        insurance_argument_accuracy=1.0,
        mean_completion_rate=1.0,
    )
    table = finetuned.comparison_table(baseline)
    assert len(table) == 6
    assert table[0]["absolute_gain"] == 1.0
